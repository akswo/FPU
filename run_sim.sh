#!/bin/bash

# 출력 파일명 정의
OUTPUT="fpu_sim"

# 소스 파일 목록 정의
SOURCES="fpu_tb.v fpu_8bit_top.v fp_adder.v fp_multiplier.v fp_divider.v"

echo "Compiling Verilog files..."
iverilog -o $OUTPUT $SOURCES

# 컴파일 성공 여부 확인 ($?는 이전 명령의 종료 코드)
if [ $? -eq 0 ]; then
    echo "Compilation successful! Running simulation..."
    vvp $OUTPUT
else
    echo "Compilation failed!"
    exit 1
fi