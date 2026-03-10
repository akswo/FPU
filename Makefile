# 도구 정의
CC = iverilog
SIM = vvp
WAVE = gtkwave

# 파일 및 타겟 정의
TARGET = fpu_sim
SRCS = fpu_tb.v fpu_8bit_top.v fp_adder.v fp_multiplier.v fp_divider.v
DUMP = fpu_wave.vcd

# 기본 타겟 (make 입력 시 실행됨)
all: run

# 컴파일
$(TARGET): $(SRCS)
	$(CC) -o $(TARGET) $(SRCS)

# 시뮬레이션 실행
run: $(TARGET)
	$(SIM) $(TARGET)

# 파형 보기 (GTKWave 실행)
wave: run
	$(WAVE) $(DUMP) &

# 생성된 파일 삭제
clean:
	rm -f $(TARGET) $(DUMP)

.PHONY: all run wave clean