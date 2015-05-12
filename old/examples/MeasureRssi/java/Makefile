all: MeasureRssi.class

RssiMsg.class:MeasureRssi.java
	javac $<

PermutationGenerator.class:MeasureRssi.java
	javac $<

MeasureRssi.class: MeasureRssi.java RssiMsg.java PermutationGenerator.java
	javac $^

RssiMsg.java: ../RssiMessages.h
	mig java -target=null -java-classname=RssiMsg $< RssiMsg -o $@
