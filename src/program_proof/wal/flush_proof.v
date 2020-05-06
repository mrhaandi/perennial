From RecordUpdate Require Import RecordSet.

From Perennial.program_proof Require Import disk_lib.
From Perennial.program_proof Require Import wal.invariant.

Section goose_lang.
Context `{!heapG Σ}.
Context `{!lockG Σ}.
Context `{!walG Σ}.

Implicit Types (v:val) (z:Z).
Implicit Types (γ: wal_names (Σ:=Σ)).
Implicit Types (s: log_state.t) (memLog: list update.t) (txns: list (u64 * list update.t)).
Implicit Types (pos: u64) (txn_id: nat).

Context (P: log_state.t -> iProp Σ).
Let N := walN.
Let circN := walN .@ "circ".

Theorem wal_wf_update_durable :
  relation.wf_preserved (update_durable) wal_wf.
Proof.
  intros s1 s2 [] Hwf ?; simpl in *; monad_inv.
  destruct Hwf as (Hwf1&Hwf2&Hwf3).
  destruct s1; split; unfold log_state.updates in *; simpl in *; eauto.
  split; eauto.
  lia.
Qed.

(* just an example, to work out the Flush proof without all the complications *)
Theorem wp_updateDurable (Q: iProp Σ) l γ :
  {{{ is_wal P l γ ∗
       (∀ σ σ' b,
         ⌜wal_wf σ⌝ -∗
         ⌜relation.denote (update_durable) σ σ' b⌝ -∗
         (P σ ={⊤ ∖ ↑N}=∗ P σ' ∗ Q))
   }}}
    Skip
  {{{ RET #(); Q}}}.
Proof.
  iIntros (Φ) "[#Hwal Hfupd] HΦ".
  iDestruct "Hwal" as "[Hwal Hcirc]".
  iInv "Hwal" as "Hinv".
  wp_call.
  iDestruct "Hinv" as (σ) "(Hinner&HP)".
  iNamed "Hinner".
  iNamed "Hdisk".
  iNamed "circ.end".
  pose proof (is_highest_txn_bound Hend_txn) as Hend_bound.
  iMod ("Hfupd" $! σ (set log_state.durable_lb (λ _, diskEnd_txn_id) σ)
          with "[% //] [%] [$HP]") as "[HP HQ]".
  { simpl.
    econstructor; monad_simpl.
    econstructor; monad_simpl; lia. }
  iSpecialize ("HΦ" with "HQ").
  iFrame "HΦ".
  iIntros "!> !>".
  iExists _; iFrame "HP".
  iSplit.
  - iPureIntro.
    eapply wal_wf_update_durable; eauto.
    { simpl; monad_simpl.
      econstructor; monad_simpl.
      econstructor; monad_simpl; lia. }
  - simpl.
    iFrame.
    iExists _, _; iFrame.
    iExists diskEnd; iFrame.
    iSplit; first by (iPureIntro; lia).
    eauto.
Qed.

Hint Unfold locked_wf : word.

Theorem wp_endGroupTxn st γ :
  {{{ wal_linv st γ }}}
    WalogState__endGroupTxn #st
  {{{ RET #(); wal_linv st γ }}}.
Proof.
  iIntros (Φ) "Hlkinv HΦ".
  iNamed "Hlkinv".
  iNamed "Hfields".
  iNamed "Hfield_ptsto".
  rewrite -wp_fupd.
  wp_call.
  rewrite /WalogState__memEnd.
  wp_loadField. wp_apply (wp_sliding__clearMutable with "His_memLog"); iIntros "His_memLog".
  iApply "HΦ".
  iModIntro.
  iDestruct (is_sliding_wf with "His_memLog") as %Hsliding_wf.
  iExists (set memLog (λ _,
                       (set slidingM.mutable (λ _ : u64, slidingM.endPos σ.(memLog)) σ.(memLog))) σ).
  simpl.
  iFrame "#".
  iSplitR "HmemLog_linv".
  { iExists _; iFrame.
    iPureIntro.
    split_and!; simpl; auto; try word.
    transitivity (int.val σ.(memLog).(slidingM.mutable)); try word.
    (* TODO: should be straightforward from here *)
    rewrite /slidingM.endPos.
    repeat word_cleanup.
    destruct Hlocked_wf.
    destruct H3.
    repeat word_cleanup.
    admit.
  }
  (* TODO: definitely not enough, need the wal invariant to ensure new values in
  read-only region are correct *)
Admitted.

Theorem simulate_flush l γ Q σ pos txn_id :
  (is_wal_inner l γ σ ∗ P σ) -∗
  diskEnd_at_least γ.(circ_name) (int.val pos) -∗
  txn_pos γ txn_id pos -∗
  (∀ (σ σ' : log_state.t) (b : ()),
      ⌜wal_wf σ⌝
        -∗ ⌜relation.denote (log_flush pos txn_id) σ σ' b⌝ -∗ P σ ={⊤ ∖ ↑N}=∗ P σ' ∗ Q) -∗
  |={⊤ ∖ ↑N}=> (∃ σ', is_wal_inner l γ σ' ∗ P σ') ∗ Q.
Proof.
  iIntros "Hinv #Hlb #Hpos_txn Hfupd".
  iDestruct "Hinv" as "[Hinner HP]".
  iNamed "Hinner".
  iNamed "Hdisk".
  iNamed "circ.end".
  iDestruct (diskEnd_is_agree_2 with "Hend_is Hlb") as %HdiskEnd_lb.
  iMod (txn_pos_valid with "Htxns_ctx Hpos_txn") as (His_txn) "Htxns_ctx"; first by solve_ndisj.
  pose proof (is_txn_bound _ _ _ His_txn).
  pose proof (is_highest_txn_bound Hend_txn).
  pose proof (wal_wf_txns_mono_pos Hwf His_txn (is_highest_weaken Hend_txn)).

  iMod ("Hfupd" $! σ (set log_state.durable_lb (λ _, Nat.max σ.(log_state.durable_lb) txn_id) σ) with "[% //] [%] HP") as "[HP HQ]".
  { simpl; monad_simpl.
    repeat (econstructor; monad_simpl; eauto).
    lia.
  }
  iFrame "HQ".
  iModIntro.
  iExists _; iFrame "HP".
  iSplit; auto.
  { iPureIntro.
    eapply wal_wf_update_durable; eauto.
    simpl; monad_simpl.
    repeat (econstructor; monad_simpl; eauto); lia.
  }
  simpl.
  iFrame.
  assert (txn_id ≤ diskEnd_txn_id)%nat.
  { destruct (decide (pos = diskEnd)); subst.
    - apply Hend_txn in His_txn; lia.
    - assert (int.val pos ≠ int.val diskEnd).
      { intros ?.
        apply n.
        word. }
      lia.
  }
  iExists installed_txn_id, diskEnd_txn_id; iFrame.
  iExists _; iFrame.
  iSplit.
  { iPureIntro.
    cut (txn_id ≤ diskEnd_txn_id)%nat; first by lia.
    lia. }
  auto.
  Grab Existential Variables.
  all: constructor.
Qed.

(* this is a dumb memory safety proof for loading nextDiskEnd when its value
doesn't matter for correctness *)
Theorem wp_load_some_nextDiskEnd st γ :
  {{{ wal_linv st γ }}}
        struct.loadF sliding.S "mutable"
          (struct.loadF WalogState.S "memLog" #st)
  {{{ (nextDiskEnd:u64), RET #nextDiskEnd; wal_linv st γ }}}.
Proof.
  iIntros (Φ) "Hinv HΦ".
  iNamed "Hinv".
  iNamed "Hfields".
  iNamed "Hfield_ptsto".
  wp_loadField.
  (* this is very bad, breaks sliding abstraction boundary *)
  iNamed "His_memLog"; iNamed "Hinv". wp_loadField.
  iApply "HΦ".
  iExists _; iFrame "# ∗".
  iExists _; iFrame "# ∗".
  iSplit; auto.
  iSplit; auto.
  iExists _, _; iFrame "# ∗".
Qed.

Theorem wp_Walog__Flush (Q: iProp Σ) l γ txn_id pos :
  {{{ is_wal P l γ ∗
      txn_pos γ txn_id pos ∗
       (∀ σ σ' b,
         ⌜wal_wf σ⌝ -∗
         ⌜relation.denote (log_flush pos txn_id) σ σ' b⌝ -∗
         (P σ ={⊤ ∖ ↑N}=∗ P σ' ∗ Q))
   }}}
    Walog__Flush #l #pos
  {{{ RET #(); Q}}}.
Proof.
  iIntros (Φ) "(#Hwal & #Hpos_txn & Hfupd) HΦ".
  destruct_is_wal.

  wp_apply util_proof.wp_DPrintf.
  wp_loadField.
  wp_apply (acquire_spec with "lk"). iIntros "(Hlocked&Hlkinv)".
  wp_loadField.
  wp_apply (wp_condBroadcast with "cond_logger").
  wp_loadField.

  wp_apply (wp_load_some_nextDiskEnd with "Hlkinv"); iIntros (x) "Hlkinv".
  wp_pures.

  wp_apply (wp_If_optional with "[] [Hlkinv Hlocked]"); [ | iAccu | ].
  {
    iIntros (Φ') "(Hlkinv&Hlocked) HΦ".
    wp_loadField.
    wp_apply (wp_endGroupTxn with "[$Hlkinv]").
    iIntros "Hlkinv".
    wp_pures.
    iApply ("HΦ" with "[$]").
  }
  iIntros "(Hlkinv&Hlocked)".
  wp_pures.

  wp_bind (For _ _ _).
  wp_apply (wp_forBreak_cond (λ b,
               wal_linv σₛ.(wal_st) γ ∗ locked γ.(lock_name) ∗
               if b then ⊤ else diskEnd_at_least γ.(circ_name) (int.val pos))%I
           with "[] [$Hlkinv $Hlocked]").
  { iIntros "!>" (Φ') "(Hlkinv&Hlocked&_) HΦ".
    wp_loadField.
    iNamed "Hlkinv".
    iNamed "Hfields".
    iNamed "Hfield_ptsto".
    wp_loadField.
    wp_pures.
    wp_if_destruct.
    - wp_loadField.
      wp_apply (wp_condWait with "[-HΦ $cond_logger $lk $Hlocked]").
      { iExists _; iFrame "∗ #".
        iExists _; by iFrame "∗ #". }
      iIntros "(Hlocked&Hlockin)".
      wp_pures.
      iApply "HΦ"; iFrame.
    - iApply "HΦ".
      iFrame "Hlocked".
      apply negb_false_iff in Heqb.
      apply bool_decide_eq_true in Heqb.
      iSplitL.
      { iExists _; iFrame "HdiskEnd_at_least Hstart_at_least ∗".
        iExists _; by iFrame "# ∗". }
      iApply (diskEnd_at_least_mono with "HdiskEnd_at_least"); auto.
  }

  iIntros "(Hlkinv&Hlocked&#HdiskEnd_lb)".
  wp_seq.
  wp_bind Skip.
  iDestruct "Hwal" as "[Hwal _]".
  iInv "Hwal" as "Hinv".
  wp_call.
  iDestruct "Hinv" as (σ) "[Hinner HP]".
  iMod (simulate_flush with "[$Hinner $HP] HdiskEnd_lb Hpos_txn Hfupd") as "[Hinv HQ]".
  iModIntro.
  iFrame "Hinv".

  wp_loadField.
  wp_apply (release_spec with "[$lk $Hlocked $Hlkinv]").
  iApply ("HΦ" with "HQ").
Qed.

End goose_lang.
