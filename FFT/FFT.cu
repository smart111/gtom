#include "..\Prerequisites.cuh"
#include "..\Functions.cuh"

void d_FFTR2C(tfloat* const d_input, tcomplex* const d_output, int const ndimensions, int3 const dimensions)
{
	cufftHandle plan;
	cufftType direction = IS_TFLOAT_DOUBLE ? CUFFT_D2Z : CUFFT_R2C;

	if(ndimensions == 1)
		CudaSafeCall((cudaError)cufftPlan1d(&plan, dimensions.x, direction, 1));
	else if(ndimensions == 2)
		CudaSafeCall((cudaError)cufftPlan2d(&plan, dimensions.y, dimensions.x, direction));
	else if(ndimensions == 3)
		CudaSafeCall((cudaError)cufftPlan3d(&plan, dimensions.z, dimensions.y, dimensions.x, direction));
	else
		throw;

	CudaSafeCall((cudaError)cufftSetCompatibilityMode(plan, CUFFT_COMPATIBILITY_NATIVE));
	#ifdef TOM_DOUBLE
		CUDA_MEASURE_TIME(CudaSafeCall((cudaError)cufftExecD2Z(plan, d_input, d_output)));
	#else
		CUDA_MEASURE_TIME(CudaSafeCall((cudaError)cufftExecR2C(plan, d_input, d_output)));
	#endif
	
	cudaDeviceSynchronize();
	
	CudaSafeCall((cudaError)cufftDestroy(plan));
}

void d_FFTR2CFull(tfloat* const d_input, tcomplex* const d_output, int const ndimensions, int3 const dimensions)
{
	tcomplex* d_unpadded;
	cudaMalloc((void**)&d_unpadded, (dimensions.x / 2 + 1) * dimensions.y * dimensions.z * sizeof(tcomplex));

	d_FFTR2C(d_input, d_unpadded, ndimensions, dimensions);
	d_HermitianSymmetryPad(d_unpadded, d_output, dimensions);

	cudaFree(d_unpadded);
}

void d_FFTC2C(tcomplex* const d_input, tcomplex* const d_output, int const ndimensions, int3 const dimensions)
{
	cufftHandle plan;
	cufftType direction = IS_TFLOAT_DOUBLE ? CUFFT_Z2Z : CUFFT_C2C;

	if(ndimensions == 1)
		CudaSafeCall((cudaError)cufftPlan1d(&plan, dimensions.x, direction, 1));
	else if(ndimensions == 2)
		CudaSafeCall((cudaError)cufftPlan2d(&plan, dimensions.y, dimensions.x, direction));
	else if(ndimensions == 3)
		CudaSafeCall((cudaError)cufftPlan3d(&plan, dimensions.z, dimensions.y, dimensions.x, direction));
	else
		throw;

	CudaSafeCall((cudaError)cufftSetCompatibilityMode(plan, CUFFT_COMPATIBILITY_NATIVE));
	#ifdef TOM_DOUBLE
		CUDA_MEASURE_TIME(CudaSafeCall((cudaError)cufftExecZ2Z(plan, d_input, d_output)));
	#else
		CUDA_MEASURE_TIME(CudaSafeCall((cudaError)cufftExecC2C(plan, d_input, d_output, CUFFT_FORWARD)));
	#endif
	
	CudaSafeCall((cudaError)cufftDestroy(plan));
}

void FFTR2C(tfloat* const h_input, tcomplex* const h_output, int const ndimensions, int3 const dimensions)
{
	size_t reallength = dimensions.x * dimensions.y * dimensions.z;
	size_t complexlength = (dimensions.x / 2 + 1) * dimensions.y * dimensions.z;

	tfloat* d_A = (tfloat*)CudaMallocFromHostArray(h_input, complexlength * sizeof(tcomplex), reallength * sizeof(tfloat));

	d_FFTR2C(d_A, (tcomplex*)d_A, ndimensions, dimensions);

	cudaMemcpy(h_output, d_A, complexlength * sizeof(tcomplex), cudaMemcpyDeviceToHost);
	cudaFree(d_A);
}

void FFTR2CFull(tfloat* const h_input, tcomplex* const h_output, int const ndimensions, int3 const dimensions)
{
	size_t reallength = dimensions.x * dimensions.y * dimensions.z;
	size_t complexlength = dimensions.x * dimensions.y * dimensions.z;

	tfloat* d_A = (tfloat*)CudaMallocFromHostArray(h_input, complexlength * sizeof(tcomplex), reallength * sizeof(tfloat));
	//tcomplex* d_B;
	//cudaMalloc((void**)&d_B, reallength * sizeof(tcomplex));

	d_FFTR2CFull(d_A, (tcomplex*)d_A, ndimensions, dimensions);

	cudaMemcpy(h_output, d_A, reallength * sizeof(tcomplex), cudaMemcpyDeviceToHost);
	cudaFree(d_A);
	//cudaFree(d_B);
}

void FFTC2C(tcomplex* const h_input, tcomplex* const h_output, int const ndimensions, int3 const dimensions)
{
	size_t complexlength = dimensions.x * dimensions.y * dimensions.z;

	tcomplex* d_A = (tcomplex*)CudaMallocFromHostArray(h_input, complexlength * sizeof(tcomplex));

	d_FFTC2C(d_A, d_A, ndimensions, dimensions);

	cudaMemcpy(h_output, d_A, complexlength * sizeof(tcomplex), cudaMemcpyDeviceToHost);
	cudaFree(d_A);
}