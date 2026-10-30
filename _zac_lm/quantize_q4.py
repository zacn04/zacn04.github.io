"""Quantize an ONNX model's MatMul weights to 4 bits (what transformers.js loads as dtype "q4").

onnxruntime renamed the quantizer (matmul_4bits_quantizer -> matmul_nbits_quantizer), so
both names are supported.
"""
import sys

import onnx

try:
    from onnxruntime.quantization.matmul_nbits_quantizer import MatMulNBitsQuantizer as Quantizer
    extra = {"bits": 4}
except ImportError:
    from onnxruntime.quantization.matmul_4bits_quantizer import MatMul4BitsQuantizer as Quantizer
    extra = {}

src, dst = sys.argv[1], sys.argv[2]
model = onnx.load(src)
try:
    quant = Quantizer(model, block_size=32, is_symmetric=True, **extra)
except TypeError:
    # Versions where the 4-bit width is implied and `bits` is not a keyword.
    quant = Quantizer(model, block_size=32, is_symmetric=True)
quant.process()
quant.model.save_model_to_file(dst, use_external_data_format=False)
print("wrote", dst)
