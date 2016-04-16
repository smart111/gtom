#include "cufft.h"
#include "Prerequisites.cuh"
#include "CTF.cuh"

#ifndef IMAGE_MANIPULATION_CUH
#define IMAGE_MANIPULATION_CUH

namespace gtom
{
	//////////////////////
	//Image Manipulation//
	//////////////////////

	//AnisotropicLowpass:
	void d_AnisotropicLowpass(tfloat* d_input, tfloat* d_output, int3 dims, tfloat* d_radiusmap, int2 anglesteps, tfloat smooth, cufftHandle* planforw, cufftHandle* planback, int batch);

	//Bandpass.cu:
	void d_Bandpass(tfloat* d_input, tfloat* d_output, int3 dims, tfloat low, tfloat high, tfloat smooth, tfloat* d_mask = NULL, cufftHandle* planforw = NULL, cufftHandle* planback = NULL, int batch = 1);
	void d_Bandpass(tcomplex* d_inputft, tcomplex* d_outputft, int3 dims, tfloat low, tfloat high, tfloat smooth, tfloat* d_mask = NULL, int batch = 1);

	//BeamTilt.cu:
	void d_BeamTilt(tcomplex* d_input, tcomplex* d_output, int2 dims, tfloat2* d_beamtilt, CTFParams* h_params, uint batch = 1);

	//Dose.cu:
	void d_DoseFilter(tfloat* d_freq, tfloat* d_output, uint length, tfloat* h_dose, tfloat3 nikoconst, uint batch = 1);

	//LocalLowpass.cu:
	void d_LocalLowpass(tfloat* d_input, tfloat* d_output, int3 dims, tfloat* d_resolution, tfloat maxprecision);

	//Norm.cu:
	enum T_NORM_MODE
	{
		T_NORM_NONE = 0,
		T_NORM_MEAN01STD = 1,
		T_NORM_PHASE = 2,
		T_NORM_STD1 = 3,
		T_NORM_STD2 = 4,
		T_NORM_STD3 = 5,
		T_NORM_OSCAR = 6,
		T_NORM_CUSTOM = 7
	};
	template <class Tmask> void d_Norm(tfloat* d_input, tfloat* d_output, size_t elements, Tmask* d_mask, T_NORM_MODE mode, tfloat scf, int batch = 1);
	void d_NormMonolithic(tfloat* d_input, tfloat* d_output, size_t elements, T_NORM_MODE mode, int batch);
	void d_NormMonolithic(tfloat* d_input, tfloat* d_output, tfloat2* d_mu, size_t elements, T_NORM_MODE mode, int batch);
	void d_NormMonolithic(tfloat* d_input, tfloat* d_output, size_t elements, tfloat* d_mask, T_NORM_MODE mode, int batch);
	void d_NormMonolithic(tfloat* d_input, tfloat* d_output, tfloat2* d_mu, size_t elements, tfloat* d_mask, T_NORM_MODE mode, int batch); 
	void d_NormBackground(tfloat* d_input, tfloat* d_output, int3 dims, uint particleradius, bool flipsign, uint batch);
	void d_Mean0Monolithic(tfloat* d_input, tfloat* d_output, size_t elements, int batch);

	//Xray.cu:
	void d_Xray(tfloat* d_input, tfloat* d_output, int3 dims, tfloat ndev = (tfloat)4.6, int region = 6, int batch = 1);
}
#endif