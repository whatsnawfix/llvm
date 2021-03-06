; RUN: opt < %s -instcombine -S | FileCheck %s
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64"

; Instcombine should be able to eliminate all of these ext casts.

declare void @use(i32)

define i64 @test1(i64 %a) {
  %b = trunc i64 %a to i32
  %c = and i32 %b, 15
  %d = zext i32 %c to i64
  call void @use(i32 %b)
  ret i64 %d
; CHECK-LABEL: @test1(
; CHECK-NOT: ext
; CHECK: ret
}
define i64 @test2(i64 %a) {
  %b = trunc i64 %a to i32
  %c = shl i32 %b, 4
  %q = ashr i32 %c, 4
  %d = sext i32 %q to i64
  call void @use(i32 %b)
  ret i64 %d
; CHECK-LABEL: @test2(
; CHECK: shl i64 %a, 36
; CHECK: %d = ashr exact i64 {{.*}}, 36
; CHECK: ret i64 %d
}
define i64 @test3(i64 %a) {
  %b = trunc i64 %a to i32
  %c = and i32 %b, 8
  %d = zext i32 %c to i64
  call void @use(i32 %b)
  ret i64 %d
; CHECK-LABEL: @test3(
; CHECK-NOT: ext
; CHECK: ret
}
define i64 @test4(i64 %a) {
  %b = trunc i64 %a to i32
  %c = and i32 %b, 8
  %x = xor i32 %c, 8
  %d = zext i32 %x to i64
  call void @use(i32 %b)
  ret i64 %d
; CHECK-LABEL: @test4(
; CHECK: = and i64 %a, 8
; CHECK: = xor i64 {{.*}}, 8
; CHECK-NOT: ext
; CHECK: ret
}

define i32 @test5(i32 %A) {
  %B = zext i32 %A to i128
  %C = lshr i128 %B, 16
  %D = trunc i128 %C to i32
  ret i32 %D
; CHECK-LABEL: @test5(
; CHECK: %C = lshr i32 %A, 16
; CHECK: ret i32 %C
}

define i32 @test6(i64 %A) {
  %B = zext i64 %A to i128
  %C = lshr i128 %B, 32
  %D = trunc i128 %C to i32
  ret i32 %D
; CHECK-LABEL: @test6(
; CHECK: %C = lshr i64 %A, 32
; CHECK: %D = trunc i64 %C to i32
; CHECK: ret i32 %D
}

define i92 @test7(i64 %A) {
  %B = zext i64 %A to i128
  %C = lshr i128 %B, 32
  %D = trunc i128 %C to i92
  ret i92 %D
; CHECK-LABEL: @test7(
; CHECK: %B = zext i64 %A to i92
; CHECK: %C = lshr i92 %B, 32
; CHECK: ret i92 %C
}

define i64 @test8(i32 %A, i32 %B) {
  %tmp38 = zext i32 %A to i128
  %tmp32 = zext i32 %B to i128
  %tmp33 = shl i128 %tmp32, 32
  %ins35 = or i128 %tmp33, %tmp38
  %tmp42 = trunc i128 %ins35 to i64
  ret i64 %tmp42
; CHECK-LABEL: @test8(
; CHECK:   %tmp38 = zext i32 %A to i64
; CHECK:   %tmp32 = zext i32 %B to i64
; CHECK:   %tmp33 = shl nuw i64 %tmp32, 32
; CHECK:   %ins35 = or i64 %tmp33, %tmp38
; CHECK:   ret i64 %ins35
}

define i8 @test9(i32 %X) {
  %Y = and i32 %X, 42
  %Z = trunc i32 %Y to i8
  ret i8 %Z
; CHECK-LABEL: @test9(
; CHECK: trunc
; CHECK: and
; CHECK: ret
}

; rdar://8808586
define i8 @test10(i32 %X) {
  %Y = trunc i32 %X to i8
  %Z = and i8 %Y, 42
  ret i8 %Z
; CHECK-LABEL: @test10(
; CHECK: trunc
; CHECK: and
; CHECK: ret
}

; PR25543
; https://llvm.org/bugs/show_bug.cgi?id=25543
; This is an extractelement.

define i32 @trunc_bitcast1(<4 x i32> %v) {
  %bc = bitcast <4 x i32> %v to i128
  %shr = lshr i128 %bc, 32
  %ext = trunc i128 %shr to i32
  ret i32 %ext

; CHECK-LABEL: @trunc_bitcast1(
; CHECK-NEXT:  %ext = extractelement <4 x i32> %v, i32 1
; CHECK-NEXT:  ret i32 %ext
}

; A bitcast may still be required.

define i32 @trunc_bitcast2(<2 x i64> %v) {
  %bc = bitcast <2 x i64> %v to i128
  %shr = lshr i128 %bc, 64
  %ext = trunc i128 %shr to i32
  ret i32 %ext

; CHECK-LABEL: @trunc_bitcast2(
; CHECK-NEXT:  %bc1 = bitcast <2 x i64> %v to <4 x i32>
; CHECK-NEXT:  %ext = extractelement <4 x i32> %bc1, i32 2
; CHECK-NEXT:  ret i32 %ext
}

; The right shift is optional.

define i32 @trunc_bitcast3(<4 x i32> %v) {
  %bc = bitcast <4 x i32> %v to i128
  %ext = trunc i128 %bc to i32
  ret i32 %ext

; CHECK-LABEL: @trunc_bitcast3(
; CHECK-NEXT:  %ext = extractelement <4 x i32> %v, i32 0
; CHECK-NEXT:  ret i32 %ext
}

; CHECK-LABEL: @trunc_shl_infloop(
; CHECK: %tmp = lshr i64 %arg, 1
; CHECK: %tmp21 = shl i64 %tmp, 2
; CHECK: %tmp2 = trunc i64 %tmp21 to i32
; CHECK: icmp sgt i32 %tmp2, 0
define void @trunc_shl_infloop(i64 %arg) {
bb:
  %tmp = lshr i64 %arg, 1
  %tmp1 = trunc i64 %tmp to i32
  %tmp2 = shl i32 %tmp1, 2
  %tmp3 = icmp sgt i32 %tmp2, 0
  br i1 %tmp3, label %bb2, label %bb1

bb1:
  %tmp5 = sub i32 0, %tmp1
  %tmp6 = sub i32 %tmp5, 1
  unreachable

bb2:
  unreachable
}


; the trunc can be replaced from value available from store
; load feeding into trunc left as-is.
declare void @consume(i8) readonly
define i1 @trunc_load_store(i8* align 2 %a) {
  store i8 0, i8 *%a, align 2
  %bca  = bitcast i8* %a to i16*
  %wide.load = load i16, i16* %bca, align 2
  %lowhalf.1 = trunc i16 %wide.load to i8
  call void @consume(i8 %lowhalf.1)
  %cmp.2 = icmp ult i16 %wide.load, 256
  ret i1 %cmp.2
; CHECK-LABEL: @trunc_load_store
; CHECK: %wide.load = load i16, i16* %bca, align 2
; CHECK-NOT: trunc
; CHECK: call void @consume(i8 0)
}


; The trunc can be replaced with the load value.
; both loads left as-is, since they have uses.
define i1 @trunc_load_load(i8* align 2 %a) {
  %pload = load i8, i8* %a, align 2
  %bca  = bitcast i8* %a to i16*
  %wide.load = load i16, i16* %bca, align 2
  %lowhalf = trunc i16 %wide.load to i8
  call void @consume(i8 %lowhalf)
  call void @consume(i8 %pload)
  %cmp.2 = icmp ult i16 %wide.load, 256
  ret i1 %cmp.2
; CHECK-LABEL: @trunc_load_load
; CHECK-NEXT: %pload = load i8, i8* %a, align 2
; CHECK-NEXT: %bca  = bitcast i8* %a to i16*
; CHECK-NEXT: %wide.load = load i16, i16* %bca, align 2
; CHECK-NEXT: call void @consume(i8 %pload)
; CHECK-NEXT: call void @consume(i8 %pload)
; CHECK-NEXT: %cmp.2 = icmp ult i16 %wide.load, 256
}

; Store and load to same memory location address generated through GEP.
; trunc can be removed by using the store value.
define void @trunc_with_gep_memaccess(i16* align 2 %p) {
  %t0 = getelementptr i16, i16* %p, i32 1
  store i16 2, i16* %t0
  %t1 = getelementptr i16, i16* %p, i32 1
  %x = load i16, i16* %t1
  %lowhalf = trunc i16 %x to i8
  call void @consume(i8 %lowhalf)
  ret void
; CHECK-LABEL: @trunc_with_gep_memaccess
; CHECK-NOT: trunc
; CHECK: call void @consume(i8 2)
}

; trunc should not be replaced since atomic load %wide.load has more than one use.
; different values can be seen by the uses of %wide.load in case of race.
define i1 @trunc_atomic_loads(i8* align 2 %a) {
  %pload = load atomic i8, i8* %a unordered, align 2
  %bca  = bitcast i8* %a to i16*
  %wide.load = load atomic i16, i16* %bca unordered, align 2
  %lowhalf = trunc i16 %wide.load to i8
  call void @consume(i8 %lowhalf)
  call void @consume(i8 %pload)
  %cmp.2 = icmp ult i16 %wide.load, 256
  ret i1 %cmp.2
; CHECK-LABEL: @trunc_atomic_loads
; CHECK: trunc
}

; trunc can be replaced since atomic load has single use.
; atomic load is also removed since use is removed.
define void @trunc_atomic_single_load(i8* align 2 %a) {
  %pload = load atomic i8, i8* %a unordered, align 2
  %bca  = bitcast i8* %a to i16*
  %wide.load = load atomic i16, i16* %bca unordered, align 2
  %lowhalf = trunc i16 %wide.load to i8
  call void @consume(i8 %lowhalf)
  call void @consume(i8 %pload)
  ret void
; CHECK-LABEL: @trunc_atomic_single_load
; CHECK-NOT: trunc
; CHECK-NOT: %wide.load = load atomic i16, i16* %bca unordered, align 2
}


; trunc cannot be replaced since load's atomic ordering is higher than unordered
define void @trunc_atomic_monotonic(i8* align 2 %a) {
  %pload = load atomic i8, i8* %a monotonic, align 2
  %bca  = bitcast i8* %a to i16*
  %wide.load = load atomic i16, i16* %bca monotonic, align 2
  %lowhalf = trunc i16 %wide.load to i8
  call void @consume(i8 %lowhalf)
  call void @consume(i8 %pload)
  ret void
; CHECK-LABEL: @trunc_atomic_monotonic
; CHECK: %wide.load = load atomic i16, i16* %bca monotonic, align 2
; CHECK: trunc
}

; trunc cannot be replaced since store size (i16) is not trunc result size (i8).
; FIXME: we could get the i8 content of trunc from the i16 store value.
define i1 @trunc_different_size_load(i16 * align 2 %a) {
  store i16 0, i16 *%a, align 2
  %bca  = bitcast i16* %a to i32*
  %wide.load = load i32, i32* %bca, align 2
  %lowhalf = trunc i32 %wide.load to i8
  call void @consume(i8 %lowhalf)
  %cmp.2 = icmp ult i32 %wide.load, 256
  ret i1 %cmp.2
; CHECK-LABEL: @trunc_different_size_load
; CHECK: %lowhalf = trunc i32 %wide.load to i8
}

declare void @consume_f(float) readonly
; bitcast required since trunc result type and %fload are different types.
; so replace the trunc with bitcast.
define i1 @trunc_avoid_bitcast(float* %b) {
  %fload = load float, float* %b
  %bca = bitcast float* %b to i64*
  %iload = load i64, i64* %bca
  %low32 = trunc i64 %iload to i32
  call void @consume_f(float %fload)
  %cmp.2 = icmp ult i32 %low32, 256
  ret i1 %cmp.2
; CHECK-LABEL: @trunc_avoid_bitcast
; CHECK-NOT: %low32 = trunc i64 %iload to i32
; CHECK: %low32.cast = bitcast float %fload to i32
; CHECK: %cmp.2 = icmp ult i32 %low32.cast, 256
}
