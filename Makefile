include .env

default: run

run:
	mix run -e 'ScriptureExtract.run()'

compile:
	mix compile
