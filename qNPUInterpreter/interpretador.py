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

import printneuron
import printtopology
import printtestbench
import gemm

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
#gui = Gui()
#gui.browseFiles()
#print(gui.filename)

print("Type of model to interpret (compatible with tflite/tensorflow): ")
for line in sys.stdin:    
    if line == "tflite\n":
        #todo: ask to provide filepath to import tflite model
        print("loading tflite model...\n")
        with open('tflite_model.tflite','rb') as file:
            tflite_model = file.read()

        os.system('python -m tf2onnx.convert --tflite tflite_model.tflite --output quantmodel.onnx --opset 10')
        os.system('python -m tf2onnx.convert --tflite tflite_model.tflite --output dequantmodel.onnx --dequantize --opset 10')
        onnx_model_quant = onnx.load('quantmodel.onnx')
        onnx_model_dequant = onnx.load('dequantmodel.onnx')
    elif line == "tensorflow":
        #todo: ask to provide filepath to import tensorflow model
        print("loading model...\n")
        model = tf.keras.models.load_model("C:\\Users\\Thomas\\source\\repos\\interpretador\\interpretador\\tensorflowmodel")
    break
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
#for node, op in node_to_node_operations:
#    if op in valid_operations:
#        synthesizable_nodes.append(node)




gemms = []
for key, value in q_node_to_node_operations.items():
    if value == 'Gemm':
        aux_gemm = gemm_class(key, q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, node_to_inputs, node_to_outputs) 
        gemms.append(aux_gemm)

synthesizable_operations = ["Relu", "Gemm"]
synthesizable_nodes      = []



print_network_data_package(node_to_node_operations, node_to_inputs, gemms)
printFrequencyDivider()
#print_top_datapath()
printDatapath()
if 'Relu' in q_node_to_node_operations.values():
    print_relu()
if 'Gemm' in q_node_to_node_operations.values():
    #print_gemm()
    printGemm()
    printGemmQuant()

#todo rest of prints










#quantized_interpreter = tf.lite.Interpreter(model_content = tflite_model)
#quantized_interpreter.allocate_tensors()
### Get input and output tensors.
#input_details = quantized_interpreter.get_input_details()
#output_details = quantized_interpreter.get_output_details()


### get details for each tensor
#all_layers_details = quantized_interpreter.get_tensor_details() 

#layer_tensor = []
#for i in range(len(all_layers_details)):
#    layer_tensor.append(quantized_interpreter.get_tensor(i))

#model object has the information about the neural network topology and weights 
# i = layer number, starting from 0
# inputs to layer 0 are the neural network inputs 
# outputs from last layer are the neural network outputs
#
# print(np.shape(model.variables[i].numpy())) prints "(x, y)"
# x number of inputs, y number of neurons
# if layer shape is of format "(z,)", layer represents bias for the previous layer
# z is the number of neurons/biases of the previous layer
# print(model.variables[0].numpy()) prints the weights

# 3.4028235e+38 max value, -3.4028235e+38 min value for float32

# select bit width precision for vhdl neural network execution (32-bit fixed point, 16-bit fixed point, 8-bit fixed point)
# larger bit count increases accuracy but increases the resulting circuit size and latency


bitwidth = 32
#bitwidth = 16
#bitwidth = 8


#quantization from float to fixed point requires a representative dataset for scale definition
test_input   = pd.read_csv('iris - iris_encoded_data_test.csv')
test_target  = pd.read_csv('iris - iris_encoded_labels_test.csv')

#obtain largest and smallest input values 
s_test_input = test_input.to_numpy()
s_test_target = test_target.to_numpy()

test_input_min  = s_test_input.min
test_input_max  = s_test_input.max
test_target_min = s_test_target.min
test_target_max = s_test_target.max

#determine scale



done = 0
i = 0
print("\n--------------------------------------------")
while done==0:
    i += 1
    try:
        print("layer %s\n" %i)
        print("activation function:\n")
        print(model.layers[i].activation._keras_api_names) #returns activation function name (in this case, ('keras.activation.relu',) )
        print("architecture")
        print(model.layers[i]._keras_api_names) #topology, expected ('keras.layers.Dense',) or ('keras.layers.Flatten',)
        print("shape:\n")
        print(np.shape(model.layers[i].weights[0].numpy()))
        print("neurons: ")
        print(model.layers[i].units) #number of neurons in the layer
        print("weights:\n")
        print(model.layers[i].weights[0].numpy())
        print("bias:\n")
        print(model.layers[i].weights[1].numpy())
    except:
        done = 1
        break

#for i in range(4):
#    print(model.layers[i].input_shape[1])

test_input   = pd.read_csv('iris - iris_encoded_data_test.csv')
test_target  = pd.read_csv('iris - iris_encoded_labels_test.csv')
results = model.evaluate(test_input, test_target)
print("test loss, test acc:", results)

#printneuron.printneuronvhd("keras.activation.relu", 5, "float32", 2)
printneuron.printneuronvhd("keras.activation.relu", 4, "float32", 1)
printneuron.printneuronvhd("keras.activation.relu", 3, "float32", 2)
printneuron.printneuronvhd("keras.activation.relu", 5, "float32", 3)
printneuron.printneuronvhd("keras.activation.relu", 5, "float32", 4)
printneuron.printneuronvhd("keras.activation.relu", 5, "float32", 5)
printtopology.printtopologyvhd(model)
#f += 1