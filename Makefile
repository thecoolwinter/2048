build:
	swift build -c release -Xswiftc -cross-module-optimization

optimize: build
	cp ./.build/release/Game ./Optimizer/Game
	cd Optimizer && caffeinate -i python3 optimize.py
	rm ./Optimizer/Game

install:
	cd Optimizer && pip3 install

clean:
	swift package clean
	rm -f ./Optimizer/Game
