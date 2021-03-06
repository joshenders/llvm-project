; RUN: llvm-reduce --test FileCheck --test-arg --check-prefixes=CHECK-ALL,CHECK-INTERESTINGNESS --test-arg %s --test-arg --input-file %s -o %t
; RUN: cat %t | FileCheck --check-prefixes=CHECK-ALL,CHECK-FINAL %s

; We cannot change the @alias to undef, because it would result in invalid IR
; (Aliasee should be either GlobalValue or ConstantExpr).

; CHECK-INTERESTINGNESS: @alias =
; CHECK-FINAL: @alias = alias void (i32), bitcast (void ()* @func to void (i32)*)

@alias = alias void (i32), void (i32)* @func

; CHECK-FINAL: @func()

define void @func(i32 %arg) {
entry:
  ret void
}
