class gemm_class:
    """objects of this class correspond to a neural network gemm (General matrix multiply) node 
    objects of this class are to be used to provide information to write the hardware description files

    this class contains the following attributes:
    name: string, corresponds to the node name
    inputs: string, corresponds to the names of the nodes that provide inputs to this gemm
    dtype: string, corresponds to the datatype used by weights
    n_neurons: int, number of neurons in layer
    n_inputs: int, number of inputs receiver by layer
    
    weights: array, corresponds to the values of weights to multiply the inputs by
    bias: array, corresponds to the values of biases to sum to the result of the previous multiplication
    
    this class contains the following methods:
    __init__: object constructor
    init_find_inputs: used by object constructor, finds values for attributes inputs, weights and bias
    find_parameters: used by init_find_inputs, finds values for weights and bias"""
    
    inputs = []
    weights = []
    bias = []
    
    def init_find_inputs(self, q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, node_to_inputs, node_to_outputs):
        #if the node name can be found in onnx_weights, search found a weight, bias, scale or zero point node
        #   check whether the node found is a weight or bias node
        #   if so, register its values in self.weights or self.bias, correspondingly
        for item in q_node_to_inputs[self.name]:
            self.find_parameters(q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, item)
        
        #then, search for node whose output corresponds to this node's input, and add to self.inputs
        for item in node_to_inputs[self.name]:
            if item in node_to_outputs.values():
                self.inputs.append(list(node_to_outputs.keys())[list(node_to_outputs.values()).index(item)])

        #todo

    def find_parameters(self, q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, item):
        for weight in onnx_weights:
            if item.find(weight) != -1:
                #if item.find("zero_point") == -1 & item.find("scale") == -1:
                ##if item.find("zero_point") != -1:
                 ##   self.zero_point = onnx_weights[weight]
                if item.find("Bias") != -1:
                #item is bias node
                    self.bias = onnx_weights[weight]
                    self.bias_zero = onnx_weights[q_node_to_inputs[item][0]].item()
                    self.bias_scale = onnx_weights[q_node_to_inputs[item][1]].item()
                    break
                else:
                #item is weight node, as it is an input and is found in the weights dictionary
                    self.weights = onnx_weights[weight]
                    self.dtype   = self.weights.dtype
                    self.n_neurons = self.weights.shape[1]
                    self.n_inputs = self.weights.shape[0]
                    self.weight_zero = onnx_weights[q_node_to_inputs[item][0]].item()
                    self.weight_scale = onnx_weights[q_node_to_inputs[item][1]].item()
                    break
            else:
            #item is input node, as it is an input and is not found in the weights dictionary
                self.input_zero = onnx_weights[q_node_to_inputs[item][0]].item()
                self.input_scale = onnx_weights[q_node_to_inputs[item][1]].item()
    def find_outputs(self, q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, node_to_inputs, node_to_outputs):
        #First, finds gemm output variable    
        output_variable = q_node_to_outputs[self.name]
        
        #Then, finds node which uses variable as its input (the layer's activation function)
        for node, input in q_node_to_inputs.items():  
            if input[0] == output_variable:
                #Then, finds the activation function's output variable
                act_func_output_variable = q_node_to_outputs[node]
                #Then, finds node that uses variable as its input (quantization node),
                #    and extracs quantization parameters
                for node, input in q_node_to_inputs.items():
                    for item in input:
                        if item == act_func_output_variable:
                            self.output_zero = onnx_weights[q_node_to_inputs[node][0]].item()
                            self.output_scale = onnx_weights[q_node_to_inputs[node][1]].item()
                break
       
        
        




    def __init__(self, key, q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, node_to_inputs, node_to_outputs):
        self.name = key
        self.init_find_inputs(q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, node_to_inputs, node_to_outputs)
        #todo: find output scale and zero_point
        self.find_outputs(q_node_to_node_operations, q_node_to_inputs, q_node_to_outputs, onnx_weights, node_to_inputs, node_to_outputs)