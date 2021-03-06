; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -basic-aa -dse -S | FileCheck %s
; RUN: opt < %s -aa-pipeline=basic-aa -passes=dse -S | FileCheck %s
target datalayout = "E-p:64:64:64-a0:0:8-f32:32:32-f64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-v64:64:64-v128:128:128"

declare void @llvm.memset.p0i8.i64(i8* nocapture, i8, i64, i1) nounwind
declare void @llvm.memset.element.unordered.atomic.p0i8.i64(i8* nocapture, i8, i64, i32) nounwind
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* nocapture, i8* nocapture, i64, i1) nounwind
declare void @llvm.memcpy.element.unordered.atomic.p0i8.p0i8.i64(i8* nocapture, i8* nocapture, i64, i32) nounwind
declare void @llvm.init.trampoline(i8*, i8*, i8*)

; **** Noop load->store tests **************************************************

; We CAN optimize volatile loads.
define void @test_load_volatile(i32* %Q) {
; CHECK-LABEL: @test_load_volatile(
; CHECK-NEXT:    [[A:%.*]] = load volatile i32, i32* [[Q:%.*]], align 4
; CHECK-NEXT:    store i32 [[A]], i32* [[Q]], align 4
; CHECK-NEXT:    ret void
;
  %a = load volatile i32, i32* %Q
  store i32 %a, i32* %Q
  ret void
}

; We can NOT optimize volatile stores.
define void @test_store_volatile(i32* %Q) {
; CHECK-LABEL: @test_store_volatile(
; CHECK-NEXT:    [[A:%.*]] = load i32, i32* [[Q:%.*]], align 4
; CHECK-NEXT:    store volatile i32 [[A]], i32* [[Q]], align 4
; CHECK-NEXT:    ret void
;
  %a = load i32, i32* %Q
  store volatile i32 %a, i32* %Q
  ret void
}

; PR2599 - load -> store to same address.
define void @test12({ i32, i32 }* %x) nounwind  {
; CHECK-LABEL: @test12(
; CHECK-NEXT:    [[TMP7:%.*]] = getelementptr { i32, i32 }, { i32, i32 }* [[X:%.*]], i32 0, i32 1
; CHECK-NEXT:    [[TMP8:%.*]] = load i32, i32* [[TMP7]], align 4
; CHECK-NEXT:    [[TMP17:%.*]] = sub i32 0, [[TMP8]]
; CHECK-NEXT:    store i32 [[TMP17]], i32* [[TMP7]], align 4
; CHECK-NEXT:    ret void
;
  %tmp4 = getelementptr { i32, i32 }, { i32, i32 }* %x, i32 0, i32 0
  %tmp5 = load i32, i32* %tmp4, align 4
  %tmp7 = getelementptr { i32, i32 }, { i32, i32 }* %x, i32 0, i32 1
  %tmp8 = load i32, i32* %tmp7, align 4
  %tmp17 = sub i32 0, %tmp8
  store i32 %tmp5, i32* %tmp4, align 4
  store i32 %tmp17, i32* %tmp7, align 4
  ret void
}

; Remove redundant store if loaded value is in another block.
define i32 @test26(i1 %c, i32* %p) {
; CHECK-LABEL: @test26(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br label [[BB3:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    br label [[BB3]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb1:
  br label %bb3
bb2:
  store i32 %v, i32* %p, align 4
  br label %bb3
bb3:
  ret i32 0
}

; Remove redundant store if loaded value is in another block.
define i32 @test27(i1 %c, i32* %p) {
; CHECK-LABEL: @test27(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br label [[BB3:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    br label [[BB3]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb1:
  br label %bb3
bb2:
  br label %bb3
bb3:
  store i32 %v, i32* %p, align 4
  ret i32 0
}

; Remove redundant store if loaded value is in another block inside a loop.
define i32 @test31(i1 %c, i32* %p, i32 %i) {
; CHECK-LABEL: @test31(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[BB1:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br label %bb1
bb1:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb2:
  ret i32 0
}

; Don't remove "redundant" store if %p is possibly stored to.
define i32 @test46(i1 %c, i32* %p, i32* %p2, i32 %i) {
; CHECK-LABEL: @test46(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[V:%.*]] = load i32, i32* [[P:%.*]], align 4
; CHECK-NEXT:    br label [[BB1:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    store i32 [[V]], i32* [[P]], align 4
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    store i32 0, i32* [[P2:%.*]], align 4
; CHECK-NEXT:    br i1 [[C]], label [[BB3:%.*]], label [[BB1]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br label %bb1
bb1:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb2:
  store i32 0, i32* %p2, align 4
  br i1 %c, label %bb3, label %bb1
bb3:
  ret i32 0
}

declare void @unknown_func()

; Remove redundant store, which is in the lame loop as the load.
define i32 @test33(i1 %c, i32* %p, i32 %i) {
; CHECK-LABEL: @test33(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[BB1:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    call void @unknown_func()
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1]], label [[BB3:%.*]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  br label %bb1
bb1:
  %v = load i32, i32* %p, align 4
  br label %bb2
bb2:
  store i32 %v, i32* %p, align 4
  ; Might read and overwrite value at %p, but doesn't matter.
  call void @unknown_func()
  br i1 %c, label %bb1, label %bb3
bb3:
  ret i32 0
}

declare void @unkown_write(i32*)

; We can't remove the "noop" store around an unkown write.
define void @test43(i32* %Q) {
; CHECK-LABEL: @test43(
; CHECK-NEXT:    [[A:%.*]] = load i32, i32* [[Q:%.*]], align 4
; CHECK-NEXT:    call void @unkown_write(i32* [[Q]])
; CHECK-NEXT:    store i32 [[A]], i32* [[Q]], align 4
; CHECK-NEXT:    ret void
;
  %a = load i32, i32* %Q
  call void @unkown_write(i32* %Q)
  store i32 %a, i32* %Q
  ret void
}

; We CAN remove it when the unkown write comes AFTER.
define void @test44(i32* %Q) {
; CHECK-LABEL: @test44(
; CHECK-NEXT:    call void @unkown_write(i32* [[Q:%.*]])
; CHECK-NEXT:    ret void
;
  %a = load i32, i32* %Q
  store i32 %a, i32* %Q
  call void @unkown_write(i32* %Q)
  ret void
}

define void @test45(i32* %Q) {
; CHECK-LABEL: @test45(
; CHECK-NEXT:    [[A:%.*]] = load i32, i32* [[Q:%.*]], align 4
; CHECK-NEXT:    store i32 [[A]], i32* [[Q]], align 4
; CHECK-NEXT:    ret void
;
  %a = load i32, i32* %Q
  store i32 10, i32* %Q
  store i32 %a, i32* %Q
  ret void
}

define i32 @test48(i1 %c, i32* %p) {
; CHECK-LABEL: @test48(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[V:%.*]] = load i32, i32* [[P:%.*]], align 4
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB0:%.*]], label [[BB0_0:%.*]]
; CHECK:       bb0:
; CHECK-NEXT:    store i32 0, i32* [[P]], align 4
; CHECK-NEXT:    br i1 [[C]], label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb0.0:
; CHECK-NEXT:    br label [[BB1]]
; CHECK:       bb1:
; CHECK-NEXT:    store i32 [[V]], i32* [[P]], align 4
; CHECK-NEXT:    br i1 [[C]], label [[BB2]], label [[BB0]]
; CHECK:       bb2:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br i1 %c, label %bb0, label %bb0.0

bb0:
  store i32 0, i32* %p
  br i1 %c, label %bb1, label %bb2

bb0.0:
  br label %bb1

bb1:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb2, label %bb0
bb2:
  ret i32 0
}

; TODO: Remove both redundant stores if loaded value is in another block inside a loop.
define i32 @test47(i1 %c, i32* %p, i32 %i) {
; CHECK-LABEL: @test47(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[V:%.*]] = load i32, i32* [[P:%.*]], align 4
; CHECK-NEXT:    br label [[BB1:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    store i32 [[V]], i32* [[P]], align 4
; CHECK-NEXT:    br i1 [[C]], label [[BB3:%.*]], label [[BB1]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br label %bb1
bb1:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb2:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb3, label %bb1
bb3:
  ret i32 0
}

; Test case from PR47887.
define void @test_noalias_store_between_load_and_store(i32* noalias %x, i32* noalias %y) {
; CHECK-LABEL: @test_noalias_store_between_load_and_store(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[LV:%.*]] = load i32, i32* [[X:%.*]], align 4
; CHECK-NEXT:    store i32 0, i32* [[Y:%.*]], align 4
; CHECK-NEXT:    store i32 [[LV]], i32* [[X]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %lv = load i32, i32* %x, align 4
  store i32 0, i32* %y, align 4
  store i32 %lv, i32* %x, align 4
  ret void
}

; Test case from PR47887. Currently we eliminate the dead `store i32 %inc, i32* %x`,
; but not the no-op `store i32 %lv, i32* %x`. That is because no-op stores are
; eliminated before dead stores for the same def.
define void @test_noalias_store_between_load_and_store_elimin_order(i32* noalias %x, i32* noalias %y) {
; CHECK-LABEL: @test_noalias_store_between_load_and_store_elimin_order(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[LV:%.*]] = load i32, i32* [[X:%.*]], align 4
; CHECK-NEXT:    store i32 0, i32* [[Y:%.*]], align 4
; CHECK-NEXT:    store i32 [[LV]], i32* [[X]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %lv = load i32, i32* %x, align 4
  %inc = add nsw i32 %lv, 1
  store i32 %inc, i32* %x, align 4
  store i32 0, i32* %y, align 4
  store i32 %lv, i32* %x, align 4
  ret void
}
