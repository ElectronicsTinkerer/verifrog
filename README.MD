# Verifrog

[insert frog logo here]

Verifrog is a test bench generation language for Verilog modules. It is designed with sequential (clocked) systems in mind although it could be used for combinational logic as well.

## Basic operation

Run the compiled executable (`build/vf`) and it will generate a verilog top level module that can be simulated (this is the test bench). Accompanying this file is a data vector file which contains all the test vectors.

example: `vf addr-test.vfl addr-vectors.dat tb_addr.v`

An example verifrog source file is provided in the `test` directory.

## Building

`flex`, `bison`, and `make` need to be installed in addition to a C compiler. With these installed, run `make` in the root directory and the `Makefile` should generate a `vf` executable in the `build` directory. You can also use `make run` to run the test contained in the `test` folder.

## Disclaimers

I currently have no plans on maintaining this project but decided to put it up on the web by popular demand of a few friends.

This project was created because I had been thinking about designing a language like this for a while and I had a lab due the following week which needed to be tested. (I know, brilliant idea to spend the entire week automating the one test bench file I could have written in an hour. Isn't automation great ;) Due to the short development time span, the code was hacked together out of code from a few other projects and likely contains errors (i.e., don't use this for testing anything you or someone else cares about).

## Known issues

The version of the hashtable used in this project has a memory leak during table resize.

