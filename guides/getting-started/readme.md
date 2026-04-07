# Getting Started

This guide explains how to get started with `build`, a task-driven build system similar to make.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add build
~~~

## Core Concepts

`build` has several core concepts:

- A {ruby Build::Rule} which represents a named build operation with typed input and output parameters.
- A {ruby Build::Rulebook} which is a collection of rules organized by process name for fast lookup.
- A {ruby Build::Controller} which manages the build graph and executes rules concurrently.

## Usage

Define rules using `Build::Rule` inside a build environment, then organize them into a rulebook:

~~~ ruby
require "build/environment"
require "build/rulebook"
require "build/rule"

environment = Build::Environment.new do
  define Build::Rule, "copy.file" do
    input :source
    output :destination
    
    apply do |parameters|
      cp parameters[:source], parameters[:destination]
    end
  end
  
  define Build::Rule, "compile.cpp" do
    input :source
    output :object
    
    apply do |parameters|
      run! "clang++", "-c", parameters[:source], "-o", parameters[:object]
    end
  end
end

rulebook = Build::Rulebook.for(environment.flatten)
~~~

### Running a Build

Use {ruby Build::Controller} to orchestrate the build graph. The controller handles dependency resolution and runs rules concurrently where possible:

~~~ ruby
require "build/controller"

controller = Build::Controller.new do |controller|
  controller.add_chain(chain, [], environment)
end

controller.run

if controller.failed?
  $stderr.puts "Build failed!"
  exit(1)
end
~~~
