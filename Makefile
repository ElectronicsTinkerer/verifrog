# Based on: https://developer.ibm.com/tutorials/au-lexyacc/

YFLAGS := -d -Wcounterexamples
CFLAGS := -Wall -pedantic -Wno-unused-function

BUILD_DIR := build
SRC_DIR := src

BIN_NAME := lc

PROG := $(BUILD_DIR)/$(BIN_NAME)

SRC_PARSE := lakeparse.tab.c 
SRC_LEX := lex.yy.c 
SRCS := lake.c ast.c astopt.c cstate.c hashtable.c semantics.c codegen.c
SRCSP := $(SRCS:%.c=$(SRC_DIR)/%.c)
OBJS := ${SRCS:.c=.o}
OBJSP :=$(SRCS:%.c=$(BUILD_DIR)/%.o)
SNAMES := ${SRCS:.c=}

CC := gcc

# .PHONY: all
all: $(BUILD_DIR) $(PROG)

$(BUILD_DIR)/lakeparse.tab.c: $(SRC_DIR)/lakeparse.y
	bison $(YFLAGS) $(SRC_DIR)/lakeparse.y -o $(BUILD_DIR)/$(SRC_PARSE)

$(BUILD_DIR)/$(SRC_LEX) $(BUILD_DIR)/lex.yy.h: $(SRC_DIR)/lex.l
	flex -o $(BUILD_DIR)/$(SRC_LEX) --header-file=$(BUILD_DIR)/lex.yy.h $<

$(PROG): $(SRCSP) $(BUILD_DIR)/$(SRC_LEX) $(BUILD_DIR)/$(SRC_PARSE) $(BUILD_DIR)/lex.yy.c
	$(CC) $(CFLAGS) $^ -o $@ -lfl -iquote$(SRC_DIR) -iquote$(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

run: all
	$(BUILD_DIR)/$(BIN_NAME) test.l1

run-vars: all
	$(BUILD_DIR)/$(BIN_NAME) test-vardecs.l1

run-funcs: all
	$(BUILD_DIR)/$(BIN_NAME) test-funcdecs.l1

clean:
	rm -rf $(BUILD_DIR)
