#include <algorithm>
#include <vector>
#include "include.cuh"
#include "System.cuh"

System::System()
{
  gravity = make_double3(0,-9.81,0);
  tol = 1e-8;
  h = 1e-3;
  timeIndex = 0;
  time = 0;

	// spike stuff
	partitions = 1;
	solverOptions.safeFactorization = true;
	solverOptions.trackReordering = true;
	solverOptions.maxNumIterations = 5000;
	preconditionerUpdateModulus = -1; // the preconditioner updates every ___ time steps
	preconditionerMaxKrylovIterations = -1; // the preconditioner updates if Krylov iterations are greater than ____ iterations
	mySolver = new SpikeSolver(partitions, solverOptions);
	m_spmv = new MySpmv(mass);
  stepKrylovIterations = 0;
  precUpdated = 0;
	// end spike stuff
}

void System::setSolverType(int solverType)
{
	switch(solverType) {
	case 0:
		solverOptions.solverType = spike::BiCGStab;
		break;
	case 1:
		solverOptions.solverType = spike::BiCGStab1;
		break;
	case 2:
		solverOptions.solverType = spike::BiCGStab2;
		break;
	case 3:
		solverOptions.solverType = spike::MINRES;
		break;
	}
}

void System::setPrecondType(int useSpike)
{
	solverOptions.precondType = useSpike ? spike::Spike : spike::None;
}

void System::setTimeStep(double step_size, double precision)
{
	h = step_size;

	// Set tolerance for Newton iteration based on the precision in positions
	// and integration step-size.
	double safety = 1;////0.5;
	tol = safety * precision / (h * h);

	// Set the tolerances for Krylov
	solverOptions.relTol = std::min(0.01 * tol, 1e-6);
	solverOptions.absTol = 1e-10;
}

void System::printSolverParams()
{
	printf("Step size: %e\n", h);
	printf("Newton tolerance: %e\n", tol);
	printf("Krylov relTol: %e  abdTol: %e\n", solverOptions.relTol, solverOptions.absTol);
	printf("Max. Krylov iterations: %d\n", solverOptions.maxNumIterations);
	printf("----------------------------\n");
}

int System::add(Body* body) {
  // TODO: make this function general for any Body
	//add the element
  body->setIndex(p_h.size()); // Indicates the Body's location in the position array
  body->setIdentifier(bodies.size()); // Indicates the number that the Body was added
	bodies.push_back(body);

	// update p
	p_h.push_back(body->pos.x);
	p_h.push_back(body->pos.y);
	p_h.push_back(body->pos.z);

  // update v
  v_h.push_back(body->vel.x);
  v_h.push_back(body->vel.y);
  v_h.push_back(body->vel.z);

  // update a
  a_h.push_back(body->acc.x);
  a_h.push_back(body->acc.y);
  a_h.push_back(body->acc.z);

	// update external force vector (gravity)
  if(body->isFixed()) {
    f_h.push_back(0);
    f_h.push_back(0);
    f_h.push_back(0);
  }
  else {
    f_h.push_back(body->mass * this->gravity.x);
    f_h.push_back(body->mass * this->gravity.y);
    f_h.push_back(body->mass * this->gravity.z);
  }


	// update the mass matrix
	for (int i = 0; i < body->numDOF; i++) {
	  //if(!body->isFixed()) {
      massI_h.push_back(i + body->numDOF * (bodies.size() - 1));
      massJ_h.push_back(i + body->numDOF * (bodies.size() - 1));
      mass_h.push_back(1.0/body->mass);
	  //}
	}

	return bodies.size();
}

int System::initializeDevice() {
	p_d = p_h;
	v_d = v_h;
	a_d = a_h;
	f_d = f_h;

	massI_d = massI_h;
	massJ_d = massJ_h;
	mass_d = mass_h;

	thrust::device_ptr<double> wrapped_device_p(CASTD1(p_d));
	thrust::device_ptr<double> wrapped_device_v(CASTD1(v_d));
	thrust::device_ptr<double> wrapped_device_a(CASTD1(a_d));
	thrust::device_ptr<double> wrapped_device_f(CASTD1(f_d));

	p = DeviceValueArrayView(wrapped_device_p, wrapped_device_p + p_d.size());
	v = DeviceValueArrayView(wrapped_device_v, wrapped_device_v + v_d.size());
	a = DeviceValueArrayView(wrapped_device_a, wrapped_device_a + a_d.size());
	f = DeviceValueArrayView(wrapped_device_f, wrapped_device_f + f_d.size());

	// create mass matrix using cusp library (shouldn't change)
	thrust::device_ptr<int> wrapped_device_I(CASTI1(massI_d));
	DeviceIndexArrayView row_indices = DeviceIndexArrayView(wrapped_device_I, wrapped_device_I + massI_d.size());

	thrust::device_ptr<int> wrapped_device_J(CASTI1(massJ_d));
	DeviceIndexArrayView column_indices = DeviceIndexArrayView(wrapped_device_J, wrapped_device_J + massJ_d.size());

	thrust::device_ptr<double> wrapped_device_V(CASTD1(mass_d));
	DeviceValueArrayView values = DeviceValueArrayView(wrapped_device_V, wrapped_device_V + mass_d.size());

	mass = DeviceView(a_d.size(), a_d.size(), mass_d.size(), row_indices, column_indices, values);
	// end create mass matrix

	return 0;
}

int System::initializeSystem() {

	initializeDevice();

	// create and setup the Spike::GPU solver
	m_spmv = new MySpmv(mass);
	mySolver = new SpikeSolver(partitions, solverOptions);
	mySolver->setup(mass);

	//bool success = mySolver->solve(*m_spmv, f, a);

	return 0;
}

int System::DoTimeStep() {
	cudaEvent_t start, stop;
	cudaEventCreate(&start);
	cudaEventCreate(&stop);
	cudaEventRecord(start, 0);

  //fixBodies();

	cusp::multiply(mass, f, a);
	//bool success = mySolver->solve(*m_spmv, f, a);
	cusp::blas::axpy(a, v, h);
	cusp::blas::axpy(v, p, h);

  time += h;
  timeIndex++;
  p_h = p_d;

  printf("Time: %f\n",time);

	cudaEventRecord(stop, 0);
	cudaEventSynchronize(stop);
	float elapsedTime;
	cudaEventElapsedTime(&elapsedTime, start, stop);

	return 0;
}

int System::fixBodies() {

  return 0;
}
