#!/bin/bash

./am57xx_generate_pin_config_data.pl -p data/genericFileFormatPadConf.txt -d data/genericFileFormatIOdelay.txt -o iopad > output/iopad.txt
./am57xx_generate_pin_config_data.pl -p data/genericFileFormatPadConf.txt -d data/genericFileFormatIOdelay.txt -o iodelay > output/iodelay.txt

