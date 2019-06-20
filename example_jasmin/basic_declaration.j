.class public compiler_hw3
.super java/lang/Object
.field public static a I = 6
.field public static b I
.method public static main([Ljava/lang/String;)V
.limit stack 50
.limit locals 50
	ldc 0   //宣告d 把0放進去STACK
	istore 0   //然後把stack裡的東西存到index 0
	getstatic compiler_hw3/a I //取得a放到Stack
	ldc 6  // stack放入6
	iadd   //加起來
	istore 0  //存到0 因為是D的位置
	iload 0   //再放到stack裡面因為print藥用
	getstatic java/lang/System/out Ljava/io/PrintStream;
	swap
	invokevirtual java/io/PrintStream/println(I)V
	return
.end method
