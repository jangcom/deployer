@echo off
deployer.pl ^
-path="./test/" ^
tester1.txt ^
tester2.dat=tester2new.dat ^
tester3.log=tester3new.log
