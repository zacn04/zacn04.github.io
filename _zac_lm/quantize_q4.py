"""Quantize an ONNX model's MatMul weights to 4 bits (what transformers.js loads as dtype "q4")."""
import sys

import onnx
from onnxruntime.quantization.matmul_4bits_quantizer import MatMul4BitsQuantizer

src, dst = sys.argv[1], sys.argv[2]
quant = MatMul4BitsQuantizer(onnx.load(src), block_size=32, is_symmetric=True)
quant.process()
quant.model.save_model_to_file(dst, use_external_data_format=False)
print("wrote", dst)
