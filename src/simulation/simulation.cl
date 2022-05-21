// The OpenCL kernel for temperature and water simulation

__constant const float groundThermalConductivity = 1.0f;
__constant const float waterThermalConductivity = 0.6089f;
__constant const float stefanBoltzmannConstant = 0.00000005670374f; // W.m-2.K-4

typedef struct {
	float solarConstant;
	float conductivity;
	// not used, but type is supposed to be 'double' which
	// depends on cl_khr_fp64
	unsigned long gameTime_bits;
	float timeScale;
	float3 solarVector;
} SimulationOptions;

float approxExp(float x) {
	return 1 / (-x + 1);
}

__kernel void simulateTemperature(
	__global float* temperature,
	__global float* newTemp,
	__global float3* vertices,
	__global float* heatCapacities,
	__global uint* verticesNeighbours,
	const float meanPointAreaTime,
	const float meanDistance,
	const SimulationOptions options
)
{
	const int start = get_global_id(0) * 512;
	for (int idx = start; idx < start + 512; idx++) {
		// Temperature in the current cell
		const int temp = temperature[idx];
		
		// In W.m-1.K-1, this is 1 assuming 100% of planet is SiO2 :/
		const float waterLevel = 0; // self.waterElevation[i];
		const float thermalConductivity = approxExp(-waterLevel/2) * (groundThermalConductivity - waterThermalConductivity) + waterThermalConductivity; // W.m-1.K-1
		const float heatCapacity = heatCapacities[idx];

		float temperatureGain = 0.0f;
		int i = start * 6;
		int end = i + 6;
		while (i < end) {
			const uint neighbourIndex = verticesNeighbours[i];
			// We compute the 1-dimensional gradient of T (temperature)
			// aka T1 - T2
			const float dT = temperature[neighbourIndex] - temp;
			// Rate of heat flow density
			const float qx = -thermalConductivity * dT / meanDistance // W.m-2
				* (1.0f - signbit(dT)); // set to 0 if dT < 0 (heat transfer only happens from hot to cold point)
			// So, we get heat transfer in J
			const float heatTransfer = qx * meanPointAreaTime;

			const float neighbourHeatCapacity = heatCapacities[neighbourIndex];
			// it is assumed neighbours are made of the exact same materials
			// as this point
			const float itemTemperatureGain = heatTransfer / neighbourHeatCapacity; // K
			newTemp[neighbourIndex] += itemTemperatureGain;
			temperatureGain -= itemTemperatureGain;
			i += 1;
		}

		// Solar irradiance
		{
			const float3 vert = vertices[idx];
			const float solarCoeff = fmax(0, dot(vert, options.solarVector) / fast_length(vert));
			// TODO: Direct Normal Irradiance? when we have atmosphere
			// So, we get heat transfer in J
			const float heatTransfer = options.solarConstant * solarCoeff * meanPointAreaTime;
			temperatureGain += heatTransfer / heatCapacity;
		}

		// Thermal radiation with Stefan-Boltzmann law
		{
			// water emissivity: 0.96
			// limestone emissivity: 0.92
			const float emissivity = 0.93f; // took a value between the two
			const float radiantEmittance = stefanBoltzmannConstant * temp * temp * temp * temp * emissivity; // W.m-2
			const float heatTransfer = radiantEmittance * meanPointAreaTime; // J
			const float temperatureLoss = heatTransfer / heatCapacity; // K
			temperatureGain -= temperatureLoss;
		}
		newTemp[idx] += temperatureGain;
	}
}
