import numpy as np
import tensorflow as tf
import functools
import struct
import pandas as pd 

from collections import deque

import sys
import os
import subprocess

import onnx
from onnx import numpy_helper

from tensorflow import keras
import tensorflow_model_optimization as tfmot

from gemm_class import gemm_class

from print_network_data_package import print_network_data_package
from print_relu import print_relu
#from print_gemm import print_gemm
from printGemmv2 import printGemm
from printGemmQuant import printGemmQuant
#from print_frequency_divider import print_frequency_divider
from printFrequencyDividerv2 import printFrequencyDivider
#from print_top_datapath import print_top_datapath
from printDatapathv2 import printDatapath

from gui import *


from google.protobuf.json_format import MessageToJson

class graph:
    def __init__(self,gdict=None):
        if gdict is None:
            gdict = []
        self.gdict = gdict

    def getVertices(self):
        return list(self.gdict.keys())

    def edges(self):
        return self.findedges()

# List vertex names
    def findedges(self):
        edgename = []
        for vrtx in self.gdict:
            for nxtvrtx in self.gdict[vrtx]:
                if {nxtvrtx, vrtx} not in edgename:
                    edgename.append({vrtx, nxtvrtx})
        return edgename

# Add new vertex
    def addVertex(self, vrtx):
        if vrtx not in self.gdict:
            self.gdict[vrtx] = []

# Add new edge
    def AddEdge(self, edge):
        edge = set(edge)
        (vrtx1, vrtx2) = tuple(edge)
        if vrtx1 in self.gdict:
            self.gdict[vrtx1].append(vrtx2)
        else:
            self.gdict[vrtx1] = [vrtx2]

# List the edge names
    def findedges(self):
        edgename = []
        for vrtx in self.gdict:
            for nxtvrtx in self.gdict[vrtx]:
                if {nxtvrtx, vrtx} not in edgename:
                    edgename.append({vrtx, nxtvrtx})
        return edgename

def find_topology(input, network_output, synthesizable_ops, node_to_node_operations, node_to_inputs, node_to_outputs, topology):
    for node_iterator, input_iterator in node_to_inputs.items():
        if input in input_iterator:
            if node_to_node_operations[node_iterator] in synthesizable_ops:
                topology.append(node_iterator)
            if node_to_outputs[node_iterator] != network_output:
                find_topology(node_to_outputs[node_iterator], network_output, synthesizable_ops, node_to_node_operations, node_to_inputs, node_to_outputs, topology)
            else:
                break
    return
while True:
    gui = Gui()
    gui.browseFiles()
    print(gui.filename)

    #print("Type of model to interpret (compatible with tflite/tensorflow): ")
    if gui.filename.find("tflite") != -1:
        with open(gui.filename,'rb') as file:
                tflite_model = file.read()

        os.system('python -m tf2onnx.convert --tflite tflite_model.tflite --output quantmodel.onnx --opset 10')
        os.system('python -m tf2onnx.convert --tflite tflite_model.tflite --output dequantmodel.onnx --dequantize --opset 10')
        onnx_model_quant = onnx.load('quantmodel.onnx')
        onnx_model_dequant = onnx.load('dequantmodel.onnx')
    else:
        quit()


#for line in sys.stdin:    
#    if line == "tflite\n":
#        #todo: ask to provide filepath to import tflite model
#        print("loading tflite model...\n")
#        with open('tflite_model.tflite','rb') as file:
#            tflite_model = file.read()

#        os.system('python -m tf2onnx.convert --tflite tflite_model.tflite --output quantmodel.onnx --opset 10')
#        os.system('python -m tf2onnx.convert --tflite tflite_model.tflite --output dequantmodel.onnx --dequantize --opset 10')
#        onnx_model_quant = onnx.load('quantmodel.onnx')
#        onnx_model_dequant = onnx.load('dequantmodel.onnx')
#    elif line == "tensorflow":
#        #todo: ask to provide filepath to import tensorflow model
#        print("loading model...\n")
#        model = tf.keras.models.load_model("C:\\Users\\Thomas\\source\\repos\\interpretador\\interpretador\\tensorflowmodel")
#    break
#Load model
#print("loading model...\n")

# Extracts quantized weights from quantized onnx model
INTIALIZERS  = onnx_model_quant.graph.initializer
onnx_weights = {}
for initializer in INTIALIZERS:
    W = numpy_helper.to_array(initializer)
    onnx_weights[initializer.name] = W


# Creates a graph to store network topology
graph_elements = {}
g = graph(graph_elements)

# Creates a dictionary to store node inputs
node_to_inputs = {}
q_node_to_inputs = {}
# Creates a dictionary to store node outputs
node_to_outputs = {}
q_node_to_outputs = {}
# Creates a dictionary to store node operations
node_to_node_operations = {}
q_node_to_node_operations = {}
# Creates a dictionary to store input shape and datatype
input_to_inputdata = {}
q_input_to_inputdata = {}

nodes = onnx_model_dequant.graph.node
node = nodes.pop()

q_nodes = onnx_model_quant.graph.node
q_node = q_nodes.pop()
# Iterates through network and stores:
#  - nodes as vertices of graph g;
#  - operation names in node_operations dictionary;
#  - inputs for each node as edges of graph g;

while True:
    node_to_node_operations[node.name] = node.op_type
    node_to_outputs[node.name] = node.output.pop()
    while True:
        try:
            input = node.input.pop()
            if node.name in node_to_inputs:
                node_to_inputs[node.name].append(input)
            else:
                node_to_inputs[node.name] = [input]
        except:
            break
    try:
        node = nodes.pop()
    except:
        break

while True:
    q_node_to_node_operations[q_node.name] = q_node.op_type
    q_node_to_outputs[q_node.name] = q_node.output.pop()
    while True:
        try:
            input = q_node.input.pop()
            if q_node.name in q_node_to_inputs:
                q_node_to_inputs[q_node.name].append(input)
            else:
                q_node_to_inputs[q_node.name] = [input]
        except:
            break
    try:
        q_node = q_nodes.pop()
    except:
        break
    
network_input = onnx_model_dequant.graph.input.pop().name
network_output = onnx_model_dequant.graph.output.pop().name 

synthesizable_operations = ['Relu', 'Gemm']
synthesizable_nodes      = []
topology = deque()
find_topology(network_input, network_output, synthesizable_operations, node_to_node_operations, node_to_inputs, node_to_outputs, topology)

gemms = []
for key, value in q_node_to_node_operations.items():
    if value == 'Gemm':
        aux_gemm = gemm_class(key, q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, node_to_inputs, node_to_outputs) 
        gemms.append(aux_gemm)

synthesizable_operations = ["Relu", "Gemm"]
synthesizable_nodes      = []

# Prints the VHDL files
print_network_data_package(node_to_node_operations, node_to_inputs, gemms)
printFrequencyDivider()
printDatapath()
if 'Relu' in q_node_to_node_operations.values():
    print_relu()
if 'Gemm' in q_node_to_node_operations.values():
    printGemm()
    printGemmQuant()
