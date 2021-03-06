#include "include.cuh"
#include <sys/stat.h>
#include <errno.h>
#include "System.cuh"
#include "Body.cuh"
#include "PDIP.cuh"
#include "JKIP.cuh"

bool updateDraw = 1;
bool wireFrame = 1;

// Create the system (placed outside of main so it is available to the OpenGL code)
System* sys;
std::string outDir = "../TEST_DRAFT/";
std::string povrayDir = outDir + "POVRAY/";
double desiredVelocity = -0.2; // Needs to be global so that renderer can access it
thrust::host_vector<double> p0_h;

#ifdef WITH_GLUT
OpenGLCamera oglcamera(camreal3(0.04,0.05,-5.00),camreal3(0.04,0.05,0),camreal3(0,1,0),.01);

// OPENGL RENDERING CODE //
void changeSize(int w, int h) {
  if(h == 0) {h = 1;}
  float ratio = 1.0* w / h;
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glViewport(0, 0, w, h);
  gluPerspective(45,ratio,.1,1000);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  gluLookAt(0.0,0.0,0.0,    0.0,0.0,-7,   0.0f,1.0f,0.0f);
}

void initScene(){
  GLfloat light_position[] = { 1.0, 1.0, 1.0, 0.0 };
  glClearColor (1.0, 1.0, 1.0, 0.0);
  glShadeModel (GL_SMOOTH);
  glEnable(GL_COLOR_MATERIAL);
  glLightfv(GL_LIGHT0, GL_POSITION, light_position);
  glEnable(GL_LIGHTING);
  glEnable(GL_LIGHT0);
  glEnable (GL_POINT_SMOOTH);
  glEnable (GL_BLEND);
  glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glHint (GL_POINT_SMOOTH_HINT, GL_DONT_CARE);
}

void drawAll()
{
  if(updateDraw){
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glFrontFace(GL_CCW);
    glCullFace(GL_BACK);
    glEnable(GL_CULL_FACE);
    glDepthFunc(GL_LEQUAL);
    glClearDepth(1.0);

    glPointSize(2);
    glLoadIdentity();

    oglcamera.Update();

    for(int i=0;i<sys->bodies.size();i++)
    {
      if(wireFrame) {
        glPushMatrix();
        double3 position = sys->bodies[i]->getPosition();
        glTranslatef(sys->p_h[3*i],sys->p_h[3*i+1],sys->p_h[3*i+2]);
        double3 geometry = sys->bodies[i]->getGeometry();
        if(geometry.y) {
          glColor3f(0.0f,1.0f,0.0f);
          glScalef(2*geometry.x, 2*geometry.y, 2*geometry.z);
          glutWireCube(1.0);
        }
        else {
          glColor3f(0.0f,0.0f,1.0f);
          glutWireSphere(geometry.x,30,30);
        }
        glPopMatrix();
      }
      else {
        glPushMatrix();
        double3 position = sys->bodies[i]->getPosition();
        glTranslatef(sys->p_h[3*i],sys->p_h[3*i+1],sys->p_h[3*i+2]);
        double3 geometry = sys->bodies[i]->getGeometry();
        if(geometry.y) {
          glColor3f(0.0f,1.0f,0.0f);
          glScalef(2*geometry.x, 2*geometry.y, 2*geometry.z);
          glutSolidCube(1.0);
        }
        else {
          glColor3f(0.0f,0.0f,1.0f);
          glutSolidSphere(geometry.x,30,30);
        }
        glPopMatrix();
      }
    }

    glutSwapBuffers();
  }
}

void renderSceneAll(){
  if(OGL){
    //if(sys->timeIndex%10==0)
    drawAll();
    p0_h = sys->p_d;
    sys->DoTimeStep();

    // Determine contact force on the container
    sys->f_contact_h = sys->f_contact_d;
    double force = 0;
    for(int i=0; i<1; i++) {
      force += sys->f_contact_h[3*i];
    }
    cout << "  Draft force: " << force << endl;

    // TODO: This is a big no-no, need to enforce motion via constraints
    // Apply motion
    sys->v_h = sys->v_d;
    if(sys->time>1.5) {
      for(int i=0;i<1;i++) {
        sys->v_h[3*i] = desiredVelocity;
        sys->v_h[3*i+1] = 0;
        sys->v_h[3*i+2] = 0;
      }
    }
    else {
      for(int i=0;i<1;i++) {
        sys->v_h[3*i] = 0;
        sys->v_h[3*i+1] = 0;
        sys->v_h[3*i+2] = 0;
      }
    }

    sys->p_d = p0_h;
    sys->v_d = sys->v_h;
    cusp::blas::axpy(sys->v, sys->p, sys->h);
    sys->p_h = sys->p_d;
    // End apply motion
  }
}

void CallBackKeyboardFunc(unsigned char key, int x, int y) {
  switch (key) {
  case 'w':
    oglcamera.Forward();
    break;

  case 's':
    oglcamera.Back();
    break;

  case 'd':
    oglcamera.Right();
    break;

  case 'a':
    oglcamera.Left();
    break;

  case 'q':
    oglcamera.Up();
    break;

  case 'e':
    oglcamera.Down();
    break;

  case 'i':
    if(wireFrame) {
      wireFrame = 0;
    }
    else {
      wireFrame = 1;
    }
  }
}

void CallBackMouseFunc(int button, int state, int x, int y) {
  oglcamera.SetPos(button, state, x, y);
}
void CallBackMotionFunc(int x, int y) {
  oglcamera.Move2D(x, y);
}
#endif
// END OPENGL RENDERING CODE //

double getRandomNumber(double min, double max)
{
  // x is in [0,1[
  double x = rand()/static_cast<double>(RAND_MAX);

  // [0,1[ * (max - min) + min is in [min,max[
  double that = min + ( x * (max - min) );

  return that;
}

int main(int argc, char** argv)
{
  // command line arguments
  // FlexibleNet <numPartitions> <numBeamsPerSide> <solverType> <usePreconditioning>
  // solverType: (0) BiCGStab, (1) BiCGStab1, (2) BiCGStab2, (3) MinRes, (4) CG, (5) CR

  double t_end = 4;
  int    precUpdateInterval = -1;
  float  precMaxKrylov = -1;
  int precondType = 1;
  int solverType = 2;
  int numPartitions = 1;
  double mu_pdip = 10;
  double alpha = 0.01; // should be [0.01, 0.1]
  double beta = 0.8; // should be [0.3, 0.8]
  int solverTypeQOCC = 1;
  int binsPerAxis = 10;
  double tolerance = 1e-4;
  if(argc==4) {
    mu_pdip = atof(argv[1]);
    tolerance = atof(argv[2]);
    solverTypeQOCC = atoi(argv[3]);
    cout << "mu_pdip = " << mu_pdip << ", tol = " << tolerance << endl;
  }

#ifdef WITH_GLUT
  bool visualize = true;
#endif
  visualize = false;

  double hh = 1e-3;
  sys = new System(solverTypeQOCC);
  sys->setTimeStep(hh);
  sys->gravity = make_double3(0,-9.81,0);
  sys->collisionDetector->setBinsPerAxis(make_uint3(12,8,8));
  sys->solver->tolerance = tolerance;

  // Create output directories
  std::stringstream outDirStream;
  outDirStream << "../TEST_DRAFT_mu" << mu_pdip << "_h" << hh << "_tol" << tolerance << "_sol" << solverTypeQOCC << "/";
  outDir = outDirStream.str();
  povrayDir = outDir + "POVRAY/";
  if(mkdir(outDir.c_str(), S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH) == -1)
  {
    if(errno != EEXIST)
    {
      printf("Error creating directory!n");
      exit(1);
    }
  }
  if(mkdir(povrayDir.c_str(), S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH) == -1)
  {
    if(errno != EEXIST)
    {
      printf("Error creating directory!n");
      exit(1);
    }
  }

  //sys->solver->maxIterations = 30;
  if(solverTypeQOCC==2) {
    dynamic_cast<PDIP*>(sys->solver)->setPrecondType(precondType);
    dynamic_cast<PDIP*>(sys->solver)->setSolverType(solverType);
    dynamic_cast<PDIP*>(sys->solver)->setNumPartitions(numPartitions);
    dynamic_cast<PDIP*>(sys->solver)->alpha = alpha;
    dynamic_cast<PDIP*>(sys->solver)->beta = beta;
    dynamic_cast<PDIP*>(sys->solver)->mu_pdip = mu_pdip;
  }
  if(solverTypeQOCC==4) {
    dynamic_cast<JKIP*>(sys->solver)->setPrecondType(precondType);
    dynamic_cast<JKIP*>(sys->solver)->setSolverType(solverType);
    dynamic_cast<JKIP*>(sys->solver)->setNumPartitions(numPartitions);
    dynamic_cast<JKIP*>(sys->solver)->careful = true;
  }

  double rMin = 0.008;
  double rMax = 0.016;
  double L = 1.0;
  double W = 0.60;
  double H = 0.80*2.5;
  double bL = 0.01;
  double bH = 0.60;
  double bW = 0.20;
  double depth = 0.25;
  double th = 0.01;
  double density = 2600;
  sys->collisionDetector->setEnvelope(rMin*.05);

  //sys->importSystem("../data_draft20K/data_129_overwrite.dat");

  // Blade
  Body* bladePtr = new Body(make_double3(0.5*L+2*th,0.5*bH+depth,0));
  bladePtr->setBodyFixed(true);
  bladePtr->setGeometry(make_double3(0.5*bL,0.5*bH,0.5*bW));
  sys->add(bladePtr);

  // Bottom
  Body* groundPtr = new Body(make_double3(0,-th,0));
  groundPtr->setBodyFixed(true);
  groundPtr->setGeometry(make_double3(0.5*L+th,th,0.5*W+th));
  sys->add(groundPtr);

  // Left
  Body* leftPtr = new Body(make_double3(-0.5*L-2*th,0.5*H+th,0));
  leftPtr->setBodyFixed(true);
  leftPtr->setGeometry(make_double3(th,0.5*H+th,0.5*W+th));
  sys->add(leftPtr);

  // Right
  Body* rightPtr = new Body(make_double3(0.5*L+2*th,0.5*H+th,0));
  rightPtr->setBodyFixed(true);
  rightPtr->setGeometry(make_double3(th,0.5*H+th,0.5*W+th));
  sys->add(rightPtr);

  // Back
  Body* backPtr = new Body(make_double3(0,0.5*H+th,-0.5*W-2*th));
  backPtr->setBodyFixed(true);
  backPtr->setGeometry(make_double3(0.5*L+th,0.5*H+th,th));
  sys->add(backPtr);

  // Front
  Body* frontPtr = new Body(make_double3(0,0.5*H+th,0.5*W+2*th));
  frontPtr->setBodyFixed(true);
  frontPtr->setGeometry(make_double3(0.5*L+th,0.5*H+th,th));
  sys->add(frontPtr);

  // Top
  Body* topPtr = new Body(make_double3(0,H+3*th,0));
  topPtr->setBodyFixed(true);
  topPtr->setGeometry(make_double3(0.5*L+th,th,0.5*W+th));
  sys->add(topPtr);

  Body* bodyPtr;
  double wiggle = 0.003;//0.003;//0.1;
  double numElementsPerSideX = L/(2.0*rMax+2.0*wiggle);
  double numElementsPerSideY = H/(2.0*rMax+2.0*wiggle);
  double numElementsPerSideZ = W/(2.0*rMax+2.0*wiggle);
  int numBodies = 0;
  // Add elements in x-direction
  for (int i = 0; i < (int) numElementsPerSideX; i++) {
    for (int j = 0; j < (int) numElementsPerSideY; j++) {
      for (int k = 0; k < (int) numElementsPerSideZ; k++) {

        double xWig = 0.8*getRandomNumber(-wiggle, wiggle);
        double yWig = 0.8*getRandomNumber(-wiggle, wiggle);
        double zWig = 0.8*getRandomNumber(-wiggle, wiggle);
        bodyPtr = new Body(make_double3((rMax+wiggle)*(2.0*((double)i)+1.0)-0.5*L+xWig,(rMax+wiggle)*(2.0*((double)j)+1.0)+yWig,(rMax+wiggle)*(2.0*((double)k)+1.0)-0.5*W+zWig));
        double rRand = getRandomNumber(rMin, rMax);
        bodyPtr->setMass(4.0*rRand*rRand*rRand*3.1415/3.0*density);
        bodyPtr->setGeometry(make_double3(rRand,0,0));
        //if(j==0) bodyPtr->setBodyFixed(true);
        numBodies = sys->add(bodyPtr);

        if(numBodies%1000==0) printf("Bodies %d\n",numBodies);
      }
    }
  }

  sys->initializeSystem();
  printf("System initialized!\n");
  //sys->printSolverParams();

#ifdef WITH_GLUT
  if(visualize)
  {
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DEPTH | GLUT_DOUBLE | GLUT_RGBA);
    glutInitWindowPosition(0,0);
    glutInitWindowSize(1024 ,512);
    glutCreateWindow("MAIN");
    glutDisplayFunc(renderSceneAll);
    glutIdleFunc(renderSceneAll);
    glutReshapeFunc(changeSize);
    glutIgnoreKeyRepeat(0);
    glutKeyboardFunc(CallBackKeyboardFunc);
    glutMouseFunc(CallBackMouseFunc);
    glutMotionFunc(CallBackMotionFunc);
    initScene();
    glutMainLoop();
  }
#endif

  // if you don't want to visualize, then output the data
  std::stringstream statsFileStream;
  statsFileStream << outDir << "statsDraft_mu" << mu_pdip << "_h" << hh << "_tol" << tolerance << "_sol" << solverTypeQOCC << ".dat";
  ofstream statStream(statsFileStream.str().c_str());
  int fileIndex = 0;
  while(sys->time < t_end)
  {
    if(sys->timeIndex%20==0) {
      std::stringstream dataFileStream;
      dataFileStream << povrayDir << "data_" << fileIndex << ".dat";
      sys->exportSystem(dataFileStream.str());
      fileIndex++;
    }

    p0_h = sys->p_d;
    sys->DoTimeStep();

    // Determine contact force on the container
    sys->f_contact_h = sys->f_contact_d;
    double weight = 0;
    for(int i=0; i<1; i++) {
      weight += sys->f_contact_h[3*i];
    }
    cout << "  Draft force: " << weight << endl;

    int numKrylovIter = 0;
    if(solverTypeQOCC==2) numKrylovIter = dynamic_cast<PDIP*>(sys->solver)->totalKrylovIterations;
    if(solverTypeQOCC==4) numKrylovIter = dynamic_cast<JKIP*>(sys->solver)->totalKrylovIterations;
    if(sys->timeIndex%10==0) statStream << sys->time << ", " << sys->bodies.size() << ", " << sys->elapsedTime << ", " << sys->totalGPUMemoryUsed << ", " << sys->solver->iterations << ", " << sys->collisionDetector->numCollisions << ", " << weight << ", " << numKrylovIter << ", " << endl;

//    if(sys->solver->iterations==1000) {
//      sys->exportSystem("../data/data_FAIL.dat");
//      sys->exportMatrices("../data");
//      cin.get();
//    }

    // TODO: This is a big no-no, need to enforce motion via constraints
    // Apply motion
    sys->v_h = sys->v_d;
    if(sys->time>1.5) {
      for(int i=0;i<1;i++) {
        sys->v_h[3*i] = desiredVelocity;
        sys->v_h[3*i+1] = 0;
        sys->v_h[3*i+2] = 0;
      }
    }
    else {
      for(int i=0;i<1;i++) {
        sys->v_h[3*i] = 0;
        sys->v_h[3*i+1] = 0;
        sys->v_h[3*i+2] = 0;
      }
    }

    sys->p_d = p0_h;
    sys->v_d = sys->v_h;
    cusp::blas::axpy(sys->v, sys->p, sys->h);
    sys->p_h = sys->p_d;
    // End apply motion
  }

  return 0;
}
