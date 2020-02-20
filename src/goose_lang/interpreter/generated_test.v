(* autogenerated by goose/cmd/test_gen *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.disk_prelude.
From Perennial.goose_lang.interpreter Require Import test_config.

(* test functions *)
From Perennial.goose_lang.examples Require Import goose_semantics.

Example testCompareAll_ok : testCompareAll #() ~~> #true := t.
Example testCompareGT_ok : testCompareGT #() ~~> #true := t.
Example testCompareGE_ok : testCompareGE #() ~~> #true := t.
Example testCompareLT_ok : testCompareLT #() ~~> #true := t.
Example testCompareLE_ok : testCompareLE #() ~~> #true := t.
Example testEncDec32Simple_ok : testEncDec32Simple #() ~~> #true := t.
Fail Example testEncDec32_ok : failing_testEncDec32 #() ~~> #true := t.
Example testEncDec64Simple_ok : testEncDec64Simple #() ~~> #true := t.
Example testEncDec64_ok : testEncDec64 #() ~~> #true := t.
Example testIterateMap_ok : testIterateMap #() ~~> #true := t.
Example testMapSize_ok : testMapSize #() ~~> #true := t.
Fail Example testFunctionOrdering_ok : failing_testFunctionOrdering #() ~~> #true := t.
Fail Example testCopySimple_ok : failing_testCopySimple #() ~~> #true := t.
Fail Example testCopyDifferentLengths_ok : failing_testCopyDifferentLengths #() ~~> #true := t.
Example testByteSliceToString_ok : testByteSliceToString #() ~~> #true := t.
Example testShortcircuitAndTF_ok : testShortcircuitAndTF #() ~~> #true := t.
Example testShortcircuitAndFT_ok : testShortcircuitAndFT #() ~~> #true := t.
Example testShortcircuitOrTF_ok : testShortcircuitOrTF #() ~~> #true := t.
Example testShortcircuitOrFT_ok : testShortcircuitOrFT #() ~~> #true := t.
Example testReverseAssignOps64_ok : testReverseAssignOps64 #() ~~> #true := t.
Fail Example testReverseAssignOps32_ok : failing_testReverseAssignOps32 #() ~~> #true := t.
Example testAdd64Equals_ok : testAdd64Equals #() ~~> #true := t.
Example testSub64Equals_ok : testSub64Equals #() ~~> #true := t.
Example testDivisionPrecedence_ok : testDivisionPrecedence #() ~~> #true := t.
Example testModPrecedence_ok : testModPrecedence #() ~~> #true := t.
Fail Example testBitwiseOpsPrecedence_ok : failing_testBitwiseOpsPrecedence #() ~~> #true := t.
Example testArithmeticShifts_ok : testArithmeticShifts #() ~~> #true := t.
Fail Example testStructUpdates_ok : failing_testStructUpdates #() ~~> #true := t.
Fail Example testNestedStructUpdate_ok : failing_testNestedStructUpdate #() ~~> #true := t.
Example testStructConstructions_ok : testStructConstructions #() ~~> #true := t.
Example testStoreInStructVar_ok : testStoreInStructVar #() ~~> #true := t.
Example testStoreInStructPointerVar_ok : testStoreInStructPointerVar #() ~~> #true := t.
Example testStandardForLoop_ok : testStandardForLoop #() ~~> #true := t.
Example testForLoopWait_ok : testForLoopWait #() ~~> #true := t.
Example testBreakFromLoopWithContinue_ok : testBreakFromLoopWithContinue #() ~~> #true := t.
Fail Example testBreakFromLoopNoContinue_ok : failing_testBreakFromLoopNoContinue #() ~~> #true := t.
Fail Example testStringAppend_ok : failing_testStringAppend #() ~~> #true := t.
Fail Example testStringLength_ok : failing_testStringLength #() ~~> #true := t.
Example testSliceOps_ok : testSliceOps #() ~~> #true := t.
Example testOverwriteArray_ok : testOverwriteArray #() ~~> #true := t.
