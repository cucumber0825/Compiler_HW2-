.class public compiler_hw3
.super java/lang/Object
.method public static main([Ljava/lang/String;)V
.limit stack 50
.limit locals 50  //以上4行 main
	ldc 20   //先丟20進來
	istore 0   //放到0位置
	iload 0   // if要用到a 先load進來
	ldc 40   // 40放進來
	isub      // 比較
	ifeq LABEL_EQ   //如果 == 就跳到 LABEL_EQ
	iload 0   //load a
	ldc 40    // 40放進來
	isub      // 比較
	ifgt LABEL_GT    // 如果大於 就跳 LABEL_GT
	ldc 666    // printf 666 用的 以下三行print
	getstatic java/lang/System/out Ljava/io/PrintStream;
	swap
	invokevirtual java/io/PrintStream/println(I)V
	goto EXIT_0
LABEL_EQ:   //執行第一個if
	ldc "a is equal to 40"
	getstatic java/lang/System/out Ljava/io/PrintStream;
	swap
	invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
	goto EXIT_0
LABEL_GT: //執行第個if
	ldc "a is larger to 40"
	getstatic java/lang/System/out Ljava/io/PrintStream;
	swap
	invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
	goto EXIT_0
EXIT_0:
	return	
.end method
