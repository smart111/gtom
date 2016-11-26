#include "Prerequisites.cuh"
#include "Angles.cuh"
#include "Binary.cuh"
#include "Correlation.cuh"
#include "FFT.cuh"
#include "Generics.cuh"
#include "Helper.cuh"
#include "ImageManipulation.cuh"
#include "Projection.cuh"
#include "Reconstruction.cuh"
#include "Relion.cuh"
#include "Transformation.cuh"

namespace gtom
{
	__global__ void BatchComplexConjMultiplyKernel(tcomplex* d_input1, tcomplex* d_input2, tcomplex* d_output, uint vectorlength, uint batch);
	__global__ void UpdateCorrelationKernel(tfloat* d_correlation, tfloat3* d_angles, uint vectorlength, uint batch, tfloat* d_bestcorrelation, tfloat* d_bestrot, tfloat* d_besttilt, tfloat* d_bestpsi);

	void d_PickSubTomograms(tcomplex* d_projectordata,
							tfloat projectoroversample,
							int3 dimsprojector,
							tcomplex* d_experimentalft,
							tfloat* d_ctf,
							int3 dimsvolume,
							uint nvolumes,
							tfloat3* h_angles,
							uint nangles,
							tfloat maskradius,
							tfloat* d_bestcorrelation,
							tfloat* d_bestrot,
							tfloat* d_besttilt,
							tfloat* d_bestpsi)
	{
		uint batchsize = 64;
		if (nvolumes > batchsize)
			throw;

		d_ValueFill(d_bestcorrelation, Elements(dimsvolume) * nvolumes, (tfloat)-1e30);
		d_ValueFill(d_bestrot, Elements(dimsvolume) * nvolumes, (tfloat)0);
		d_ValueFill(d_besttilt, Elements(dimsvolume) * nvolumes, (tfloat)0);
		d_ValueFill(d_bestpsi, Elements(dimsvolume) * nvolumes, (tfloat)0);

		tfloat3* d_angles = (tfloat3*)CudaMallocFromHostArray(h_angles, nangles * sizeof(tfloat3));

		tcomplex* d_projectedft;
		cudaMalloc((void**)&d_projectedft, ElementsFFT(dimsvolume) * batchsize * sizeof(tcomplex));
		tcomplex* d_projectedftctf;
		cudaMalloc((void**)&d_projectedftctf, ElementsFFT(dimsvolume) * batchsize * sizeof(tcomplex));
		tfloat* d_projected;
		cudaMalloc((void**)&d_projected, Elements(dimsvolume) * batchsize * sizeof(tfloat));

		cufftHandle planforw = d_FFTR2CGetPlan(3, dimsvolume, batchsize);
		cufftHandle planback = d_IFFTC2RGetPlan(3, dimsvolume, batchsize);
		
		for (uint b = 0; b < nangles; b += batchsize)
		{
			uint curbatch = tmin(batchsize, nangles - b);

			if (curbatch != batchsize)
			{
				cufftDestroy(planforw);
				cufftDestroy(planback);
				planforw = d_FFTR2CGetPlan(3, dimsvolume, curbatch);
				planback = d_IFFTC2RGetPlan(3, dimsvolume, curbatch);
			}

			d_rlnProject(d_projectordata, dimsprojector, d_projectedft, dimsvolume, h_angles + b, projectoroversample, curbatch);

			for (uint v = 0; v < nvolumes; v++)
			{
				// Multiply by experimental CTF, norm in realspace, go back into Fourier space for convolution
				d_ComplexMultiplyByVector(d_projectedft, d_ctf + ElementsFFT(dimsvolume) * v, d_projectedftctf, ElementsFFT(dimsvolume), curbatch);
				d_IFFTC2R(d_projectedftctf, d_projected, &planback);
				d_NormMonolithic(d_projected, d_projected, Elements(dimsvolume), T_NORM_MEAN01STD, curbatch);
					//d_WriteMRC(d_projected, toInt3(dimsvolume.x, dimsvolume.y, dimsvolume.z * curbatch), "d_projected.mrc");
				d_FFTR2C(d_projected, d_projectedftctf, &planforw);

				// Multiply current experimental volume by conjugate references
				{
					int TpB = 128;
					dim3 grid = dim3((ElementsFFT(dimsvolume) + TpB - 1) / TpB, 1, 1);
					BatchComplexConjMultiplyKernel << <grid, TpB >> > (d_experimentalft + ElementsFFT(dimsvolume) * v, d_projectedftctf, d_projectedftctf, ElementsFFT(dimsvolume), curbatch);
				}

				d_IFFTC2R(d_projectedftctf, d_projected, &planback);
					//d_WriteMRC(d_projected, toInt3(dimsvolume.x, dimsvolume.y, dimsvolume.z * curbatch), "d_correlation_individual.mrc");

				// Update correlation and angles with best values
				{
					int TpB = 128;
					dim3 grid = dim3((ElementsFFT(dimsvolume) + TpB - 1) / TpB, 1, 1);
					UpdateCorrelationKernel <<<grid, TpB>>> (d_projected, 
															d_angles + b, 
															Elements(dimsvolume), 
															curbatch, 
															d_bestcorrelation + Elements(dimsvolume) * v, 
															d_bestrot + Elements(dimsvolume) * v, 
															d_besttilt + Elements(dimsvolume) * v, 
															d_bestpsi + Elements(dimsvolume) * v);
				}
				
				//d_WriteMRC(d_bestcorrelation + Elements(dimsvolume) * v, dimsvolume, "d_correlation_best.mrc");
			}
		}

		cufftDestroy(planforw);
		cufftDestroy(planback);

		// Normalize correlation by local standard deviation
		{
			d_IFFTC2R(d_experimentalft, d_projected, 3, dimsvolume, nvolumes);
			for (uint v = 0; v < nvolumes; v++)
				d_LocalStd(d_projected + Elements(dimsvolume) * v, dimsvolume, maskradius, d_projected + Elements(dimsvolume) * v);

			//d_WriteMRC(d_projected, toInt3(dimsvolume.x, dimsvolume.y, dimsvolume.z * nvolumes), "d_localstd.mrc");

			d_DivideSafeByVector(d_bestcorrelation, d_projected, d_bestcorrelation, Elements(dimsvolume) * nvolumes);
		}

		cudaFree(d_projected);
		cudaFree(d_projectedftctf);
		cudaFree(d_projectedft);
		cudaFree(d_angles);
	}

	__global__ void BatchComplexConjMultiplyKernel(tcomplex* d_input1, tcomplex* d_input2, tcomplex* d_output, uint vectorlength, uint batch)
	{
		for (uint id = blockIdx.x * blockDim.x + threadIdx.x; id < vectorlength; id += gridDim.x * blockDim.x)
		{
			tcomplex input1 = d_input1[id];

			for (uint b = 0; b < batch; b++)
				d_output[b * vectorlength + id] = cmul(input1, cconj(d_input2[b * vectorlength + id]));
		}
	}

	__global__ void UpdateCorrelationKernel(tfloat* d_correlation, tfloat3* d_angles, uint vectorlength, uint batch, tfloat* d_bestcorrelation, tfloat* d_bestrot, tfloat* d_besttilt, tfloat* d_bestpsi)
	{
		__shared__ tfloat3 s_angles[512];
		for (uint i = threadIdx.x; i < batch; i += blockDim.x)
			s_angles[i] = d_angles[i];

		for (uint id = blockIdx.x * blockDim.x + threadIdx.x; id < vectorlength; id += gridDim.x * blockDim.x)
		{
			tfloat bestcorrelation = d_bestcorrelation[id];
			tfloat3 bestangle = tfloat3(d_bestrot[id], d_besttilt[id], d_bestpsi[id]);

			for (uint b = 0; b < batch; b++)
			{
				tfloat newcorrelation = d_correlation[b * vectorlength + id];
				if (newcorrelation > bestcorrelation)
				{
					bestcorrelation = newcorrelation;
					bestangle = s_angles[b];
				}
			}

			d_bestcorrelation[id] = bestcorrelation;
			d_bestrot[id] = bestangle.x;
			d_besttilt[id] = bestangle.y;
			d_bestpsi[id] = bestangle.z;
		}
	}
}