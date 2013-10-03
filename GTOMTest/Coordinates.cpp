#include "Prerequisites.h"

TEST(ImageManipulation, Coordinates)
{
	cudaDeviceReset();

	//Case 1:
	{
		int2 dims = {16, 16};
		tfloat* d_input = (tfloat*)CudaMallocFromBinaryFile("Data\\ImageManipulation\\Input_Cart2Polar_1.bin");
		tfloat* desired_output = (tfloat*)MallocFromBinaryFile("Data\\ImageManipulation\\Output_Cart2Polar_1.bin");
		int2 polardims = GetCart2PolarSize(dims);
		tfloat* d_output;
		cudaMalloc((void**)&d_output, polardims.x * polardims.y * sizeof(tfloat));
		
		d_Cart2Polar(d_input, d_output, dims, 1);
		tfloat* h_output = (tfloat*)MallocFromDeviceArray(d_output, polardims.x * polardims.y * sizeof(tfloat));
	
		double MeanRelative = GetMeanRelativeError((tfloat*)desired_output, (tfloat*)h_output, polardims.x * polardims.y);
		ASSERT_LE(MeanRelative, 3e-3);

		cudaFree(d_input);
		cudaFree(d_output);
		free(desired_output);
		free(h_output);
	}

	//Case 2:
	{
		int2 dims = {15, 15};
		tfloat* d_input = (tfloat*)CudaMallocFromBinaryFile("Data\\ImageManipulation\\Input_Cart2Polar_2.bin");
		tfloat* desired_output = (tfloat*)MallocFromBinaryFile("Data\\ImageManipulation\\Output_Cart2Polar_2.bin");
		int2 polardims = GetCart2PolarSize(dims);
		tfloat* d_output;
		cudaMalloc((void**)&d_output, polardims.x * polardims.y * sizeof(tfloat));

		tfloat* h_input = (tfloat*)MallocFromDeviceArray(d_input, dims.x * dims.y * sizeof(tfloat));
		
		d_Cart2Polar(d_input, d_output, dims, 1);
		tfloat* h_output = (tfloat*)MallocFromDeviceArray(d_output, polardims.x * polardims.y * sizeof(tfloat));
	
		double MeanRelative = GetMeanRelativeError((tfloat*)desired_output, (tfloat*)h_output, polardims.x * polardims.y);
		ASSERT_LE(MeanRelative, 3e-3);

		cudaFree(d_input);
		cudaFree(d_output);
		free(desired_output);
		free(h_output);
	}

	cudaDeviceReset();
}