.class public compiler_hw3
.super java/lang/Object
.method public static main([Ljava/lang/String;)V
.limit stack 50
.limit locals 50  //1~5行是main
	ldc 1   //a =1
	istore 0   //存到 index 0
LABEL_BEGIN:   //開始while
	iload 0    // 把a load進來 
	ldc 6		//把6放進來
	isub 		//stack下面減上面,也就是a-6
	iflt LABEL_TRUE   //如果比0小就跳到label
	goto LABEL_FALSE  //不然就goto LABEL_FALSE
LABEL_TRUE:  //while 內部敘述
	iload 0
	getstatic java/lang/System/out Ljava/io/PrintStream;
	swap
	invokevirtual java/io/PrintStream/println(I)V  //以上4行print(a)
	iload 0  //把a load 近來
	ldc 1    // 再放1
	iadd	// +1
	istore 0   //存回
	goto LABEL_BEGIN
LABEL_FALSE:
	goto EXIT_0
EXIT_0:
	return
.end method
