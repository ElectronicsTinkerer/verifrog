# Based on: https://developer.ibm.com/tutorials/au-lexyacc/

YFLAGS := -d -Wcounterexamples
CFLAGS := -Wall -pedantic -Wno-unused-function

BUILD_DIR := build
SRC_DIR := src

BIN_NAME := vf

PROG := $(BUILD_DIR)/$(BIN_NAME)

SRC_PARSE := parse.tab.c 
SRC_LEX := lex.yy.c 
SRCS := verifrog.c hashtable.c event.c
SRCSP := $(SRCS:%.c=$(SRC_DIR)/%.c)
OBJS := ${SRCS:.c=.o}
OBJSP :=$(SRCS:%.c=$(BUILD_DIR)/%.o)
SNAMES := ${SRCS:.c=}

CC := gcc

# .PHONY: all
all: $(BUILD_DIR) $(PROG)

$(BUILD_DIR)/$(SRC_PARSE): $(SRC_DIR)/parse.y
	bison $(YFLAGS) $(SRC_DIR)/parse.y -o $(BUILD_DIR)/$(SRC_PARSE)

$(BUILD_DIR)/$(SRC_LEX) $(BUILD_DIR)/lex.yy.h: $(SRC_DIR)/lex.l
	flex -o $(BUILD_DIR)/$(SRC_LEX) --header-file=$(BUILD_DIR)/lex.yy.h $<

$(PROG): $(SRCSP) $(BUILD_DIR)/$(SRC_LEX) $(BUILD_DIR)/$(SRC_PARSE) $(BUILD_DIR)/lex.yy.c
	$(CC) $(CFLAGS) $^ -o $@ -lfl -iquote$(SRC_DIR) -iquote$(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

run: all
	$(BUILD_DIR)/$(BIN_NAME) test/test.vfl

clean:
	rm -rf $(BUILD_DIR)
