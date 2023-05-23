# Basics_to_ASICs_tutorial
In this tutorial you will learn how to ....

## Prerequisites:
* GNU Make
* Python 3.6+ with pip and virtualenv
* Git 2.22+
* Docker 19.03.12+
#### On Ubuntu:
```
apt install -y build-essential python3 python3-venv python3-pip
```
Docker Installation instructions: https://docs.docker.com/engine/install/ubuntu/
#### On Mac:
Get [Homebrew](https://brew.sh/)
Then:
```
brew install python make
brew install –-cask docker
```
Other tools needed:
* [Klayout](https://www.klayout.de/build.html)
* [GTKWave](https://sourceforge.net/projects/gtkwave/)

## OpenLane Installation:
```
git clone https://github.com/The-OpenROAD-Project/Openlane.git
cd Openlane/
make
make test # A 5-min test that ensures that Openlane and the pdk were properly installed
```
