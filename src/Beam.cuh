/*
 * Beam.cuh
 *
 *  Created on: Sep 20, 2013
 *      Author: melanz
 */

#ifndef BEAM_CUH_
#define BEAM_CUH_

#include "include.cuh"
#include "System.cuh"
#include "PhysicsItem.cuh"

class System;
class Beam : public PhysicsItem {
  friend class System;
private:

  double3 p_n0;
  double3 p_dn0;
  double3 p_n1;
  double3 p_dn1;

	double3 v_n0;
	double3 v_dn0;
	double3 v_n1;
	double3 v_dn1;

  double3 a_n0;
  double3 a_dn0;
  double3 a_n1;
  double3 a_dn1;

	double density;
	double elasticModulus;

	double3 contactGeometry;
	System* sys;

public:
	Beam() {
	  numDOF = 12;
	  identifier = 0;
	  index = 0;
	  sys = 0;
	  collisionFamily = -1;

		// create test element!
	  p_n0 = make_double3(0, 0, 0);
	  p_dn0 = make_double3(1.0, 0, 0);
	  p_n1 = make_double3(1.0, 0, 0);
	  p_dn1 = make_double3(1.0, 0, 0);

    v_n0 = make_double3(0, 0, 0);
    v_dn0 = make_double3(0, 0, 0);
    v_n1 = make_double3(0, 0, 0);
    v_dn1 = make_double3(0, 0, 0);

    a_n0 = make_double3(0, 0, 0);
    a_dn0 = make_double3(0, 0, 0);
    a_n1 = make_double3(0, 0, 0);
    a_dn1 = make_double3(0, 0, 0);

		density = 7200.0;
		elasticModulus = 2.0e7;

		contactGeometry = make_double3(0.02,1.0,10);
	}

	Beam(double3 node0, double3 node1) {
    numDOF = 12;
    identifier = 0;
    index = 0;
    sys = 0;
    collisionFamily = -1;

    // create test element!
    double l = length(node0-node1);
    double3 dir = (node1-node0)/l;
    p_n0 = node0;
    p_dn0 = dir;
    p_n1 = node1;
    p_dn1 = dir;

    v_n0 = make_double3(0, 0, 0);
    v_dn0 = make_double3(0, 0, 0);
    v_n1 = make_double3(0, 0, 0);
    v_dn1 = make_double3(0, 0, 0);

    a_n0 = make_double3(0, 0, 0);
    a_dn0 = make_double3(0, 0, 0);
    a_n1 = make_double3(0, 0, 0);
    a_dn1 = make_double3(0, 0, 0);

    density = 7200.0;
    elasticModulus = 2.0e7;

    contactGeometry = make_double3(0.02,l,10);
  }

  Beam(double3 node0, double3 dnode0, double3 node1, double3 dnode1, double length) {
    numDOF = 12;
    identifier = 0;
    index = 0;
    sys = 0;
    collisionFamily = -1;

    // create test element!
    p_n0 = node0;
    p_dn0 = dnode0;
    p_n1 = node1;
    p_dn1 = dnode1;

    v_n0 = make_double3(0, 0, 0);
    v_dn0 = make_double3(0, 0, 0);
    v_n1 = make_double3(0, 0, 0);
    v_dn1 = make_double3(0, 0, 0);

    a_n0 = make_double3(0, 0, 0);
    a_dn0 = make_double3(0, 0, 0);
    a_n1 = make_double3(0, 0, 0);
    a_dn1 = make_double3(0, 0, 0);

    density = 7200.0;
    elasticModulus = 2.0e7;

    contactGeometry = make_double3(0.02,length,10);
  }

	double3 getPosition_node0()
	{
	  return p_n0;
	}
  double3 getPosition_node1()
  {
    return p_n1;
  }

  double3 getVelocity_node0()
  {
    return v_n0;
  }

  double3 getVelocity_node1()
  {
    return v_n1;
  }

  double getDensity()
  {
    return density;
  }
  double getElasticModulus()
  {
    return elasticModulus;
  }
  void setDensity(double density)
  {
    this->density = density;
  }
  void setElasticModulus(double elasticModulus)
  {
    this->elasticModulus = elasticModulus;
  }

  double3 getGeometry()
  {
    return contactGeometry;
  }
  void setRadius(double radius)
  {
    this->contactGeometry.x = radius;
  }
  void setNumContactPoints(int numPoints)
  {
    this->contactGeometry.z = (double)numPoints;
  }
  double3 transformNodalToCartesian(double xi);
  int addBeam(int j);
};

#endif /* BEAM_CUH_ */
