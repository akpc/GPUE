/*** lattice.cc - GPUE: Split Operator based GPU solver for Nonlinear 
Schrodinger Equation, Copyright (C) 2011-2015, Lee J. O'Riordan 
<loriordan@gmail.com>, Tadhg Morgan, Neil Crowley. 
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are 
met:

1. Redistributions of source code must retain the above copyright 
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright 
notice, this list of conditions and the following disclaimer in the 
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its 
contributors may be used to endorse or promote products derived from 
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

//######################################################################################################################

#include "../include/lattice.h"
#include <iostream>

using namespace LatticeGraph;

//######################################################################################################################
//####################################    Ceiling Cat & Basement Cat     ###############################################
//######################################################################################################################

Lattice::Lattice(){
}

Lattice::~Lattice(){
	this->getVortices().clear();
	this->getEdges().clear();
}

//######################################################################################################################
//####################################            Get stuff              ###############################################
//######################################################################################################################

std::vector< std::shared_ptr<Node> >& Lattice::getVortices(){
	return this->vortices;
}

std::shared_ptr<Node> Lattice::getVortexIdx(unsigned int idx){
	return getVortices().at(idx);
}

/***
 * Gets the location of the Node with UID uid.
 */
unsigned int Lattice::getVortexIdxUid(unsigned int uid){
	for (int ii=0; ii< getVortices().size(); ++ii){
		if(this->Lattice::getVortexIdx(ii)->getUid()== uid){
			return ii;
		}
	}
	return -1;
}

/***
 * Gets the the Node with UID uid. Assumes Node exists.
 */
std::shared_ptr<Node> Lattice::getVortexUid(unsigned int uid){
	for (std::shared_ptr<Node> n : this->Lattice::getVortices()){
		if(n->getUid()== uid){
			return n;
		}
	}
	return NULL;
}

double Lattice::getVortexDistance(std::shared_ptr<Node> n1, std::shared_ptr<Node> n2){
	return sqrt(pow(n1->getData().coords.x - n2->getData().coords.x,2)
	            +  pow(n1->getData().coords.y - n2->getData().coords.y,2));
}

std::shared_ptr<Edge> Lattice::getEdgeIdx(unsigned int idx){
	return getEdges().at(idx);
}

/***
 * Gets the location of the Edge with UID uid.
 */
unsigned int Lattice::getEdgeIdxUid(unsigned int uid){
	for (int ii=0; ii< getEdges().size(); ++ii){
		if(this->Lattice::getEdgeIdx(ii)->getUid()== uid){
			return ii;
		}
	}
	return -1;
}

/***
 * Gets the the Edge with UID uid. Assumes Node exists.
 */
std::shared_ptr<Edge> Lattice::getEdgeUid(unsigned int uid){
	for (std::shared_ptr<Edge> e : this->Lattice::getEdges()){
		if(e->getUid()== uid){
			return e;
		}
	}
	return NULL;
}

std::vector< std::shared_ptr<Edge> >& Lattice::getEdges(){
	return this->edges;
}

//######################################################################################################################
//####################################             Set stuff             ###############################################
//######################################################################################################################

void Lattice::setVortex(unsigned int idx, std::shared_ptr<Node> n){
	this->Lattice::getVortices().at(idx)=(n);
}

void Lattice::setEdge(unsigned int idx, std::shared_ptr<Edge> e){
	this->Lattice::getEdges().at(idx)=(e);
}

//######################################################################################################################
//####################################              + stuff              ###############################################
//######################################################################################################################

void Lattice::createEdges(unsigned int radius){
	std::shared_ptr<Edge> e;
	for(int ii=0; ii< this->Lattice::getVortices().size(); ++ii){
		//std::cout << "ii=" << ii << "   ";
		std::cout << "Got here ii " << ii << std::endl;
		for(int jj=ii+1; jj < this->Lattice::getVortices().size(); ++jj){
			if(Lattice::getVortexDistance(this->getVortexIdx(ii),this->getVortexIdx(jj)) < radius ) {
				std::cout << "Got here jj " << jj << std::endl;
				e.reset(new Edge ( this->getVortexIdx(ii), this->getVortexIdx(jj) ));
				this->Lattice::addEdge(e,this->getVortexIdx(ii),this->getVortexIdx(jj));
			}
		}
	}
}

void Lattice::addVortex(std::shared_ptr<Node> n){
	this->Lattice::getVortices().push_back((n));
}

void Lattice::addEdge(std::shared_ptr<Edge> e){
	this->addEdge(e, e->getVortex(0).lock(), e->getVortex(1).lock());
}

void Lattice::addEdge(std::shared_ptr<Edge> e, std::shared_ptr<Node> n1, std::shared_ptr<Node> n2){
	this->Lattice::getEdges().push_back((e));
	std::weak_ptr<Edge> e1 = e;
	std::weak_ptr<Edge> e2 = e;
	n1->addEdge(e1);
	n2->addEdge(e2);
}

//######################################################################################################################
//####################################              - stuff              ###############################################
//######################################################################################################################

void Lattice::removeVortex(std::shared_ptr<Node> n){
	this->Lattice::removeVortex(this->Lattice::getVortexIdxUid(n->getUid()));
}

void Lattice::removeVortex(unsigned int idx){
	this->Lattice::getVortices().erase(this->Lattice::getVortices().begin() + idx);
}

void Lattice::removeEdge(std::shared_ptr<Edge> e){
	e->getVortex(0).lock()->removeEdge(e->getUid());
	e->getVortex(1).lock()->removeEdge(e->getUid());
	this->Lattice::getEdges().erase(this->Lattice::getEdges().begin() + this->Lattice::getEdgeIdxUid(e->getUid()));
}

void Lattice::removeEdge(unsigned int idx){
	std::shared_ptr<Edge> e = this->getEdges().at(idx);
	e->getVortex(0).lock()->removeEdge(e->getUid());
	e->getVortex(1).lock()->removeEdge(e->getUid());
	this->Lattice::getEdges().erase(this->Lattice::getEdges().begin() + idx);
}

void Lattice::removeEdge(std::shared_ptr<Node> n1, std::shared_ptr<Node> n2){
	std::weak_ptr<Edge> e = this->Lattice::isConnected(n1,n2);
	if(e.lock() != NULL ){
		n1->removeEdge(e.lock()->getUid());
		n2->removeEdge(e.lock()->getUid());
		this->Lattice::removeEdge(e.lock());
	}
	else{
		std::cout << "Node{" << n1->getUid() << "} and Node{" << n2->getUid() << "} were unconnected." << std::endl;
	}

}

void Lattice::removeEdges(std::shared_ptr<Node> n1){
	//n1->removeEdges();
}

//######################################################################################################################
//####################################         Generate stuff            ###############################################
//######################################################################################################################

/**
 * Problem with nodes not returning the correct connection.
 */
void Lattice::genAdjMat(unsigned int *mat){
	int idx1, idx2, idx;
	idx1 = 0; idx2 = 0; idx=0;
	for(std::shared_ptr<Node> n : this->Lattice::getVortices()){
		idx1=this->getVortexIdxUid(n->getUid());
		for(std::weak_ptr<Edge> e : n->getEdges()){
			idx2 = this->getVortexIdxUid(n->getConnectedNode(e.lock())->getUid());
			std::cout << "this=" << n->getUid() << "   connected=" << n->getConnectedNode(e.lock())->getUid() << std::endl;
			idx = idx1*this->Lattice::getVortices().size() + idx2;
			std::cout << "idx1=" << idx1 << "   idx2=" << idx2 << " idx=" << idx << "\n" << std::endl;
			mat[idx] = 1;
		}
	}
}

/**
 *
 * Outputs adjacency matrix in format for copy/paste into Mathematica.
 */
void Lattice::adjMatMtca(unsigned int *mat){
	unsigned int size = this->Lattice::getVortices().size();
	std::cout << "{";
	for(int i = 0; i < size; ++i){
		std::cout << "{";
		for(int j = 0; j < size; ++j){
			std::cout << mat[i*size + j];
			if(j<size-1)
				std::cout <<",";
			else
				std::cout << "}";
		}
		if(i<size-1)
			std::cout <<",";
		std::cout << std::endl;
	}
	std::cout << "}" << std::endl;
}

//######################################################################################################################
//####################################           Check stuff             ###############################################
//######################################################################################################################

std::weak_ptr<Edge> Lattice::isConnected(std::shared_ptr<Node> n1, std::shared_ptr<Node> n2){

	if(n1->getUid() != n2->getUid()){
		for(std::weak_ptr<Edge> e1 : n1->getEdges()){
			if(e1.lock()->isMember(n2)){
				return e1;
			}
		}
	}
	return std::weak_ptr<Edge> ();
}