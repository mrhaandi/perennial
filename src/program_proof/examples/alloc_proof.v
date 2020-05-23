From RecordUpdate Require Import RecordSet.
From Perennial.Helpers Require Import Map.

From Perennial.goose_lang Require Import crash_modality.

From Goose.github_com.mit_pdos.perennial_examples Require Import alloc.
From Perennial.program_proof Require Import proof_prelude.
From Perennial.goose_lang.lib Require Import into_val.

(* TODO: upstream this *)
Lemma gset_eq `{Countable A} (c1 c2: gset A) :
  (forall (x:A), x ∈ c1 ↔ x ∈ c2) → c1 = c2.
Proof.
  intros Hexteq.
  destruct c1 as [c1], c2 as [c2].
  f_equal.
  apply map_eq.
  rewrite /elem_of /gset_elem_of/mapset.mapset_elem_of /= in Hexteq.
  intros.
  destruct (c1 !! i) eqn:Hc1;
    destruct (c2 !! i) eqn:Hc2; auto.
  - destruct u, u0; auto.
  - destruct u; apply Hexteq in Hc1.
    congruence.
  - destruct u; apply Hexteq in Hc2.
    congruence.
Qed.

Instance unit_IntoVal : IntoVal ().
Proof.
  refine {| to_val := λ _, #();
            IntoVal_def := ();
         |}.
  intros [] [] _; auto.
Defined.

Instance unit_IntoValForType : IntoValForType unit_IntoVal (struct.t unit.S).
Proof.
  constructor; auto.
Qed.

(* state representation types (defined here since modules can't be in sections) *)
Module alloc.
  Record t :=
    mk { free: gset u64; }.
  Global Instance _eta : Settable _ := settable! mk <free>.
  Global Instance _witness : Inhabited t := populate!.
End alloc.

Section goose.
Context `{!heapG Σ}.
Context `{!lockG Σ}.

Let allocN := nroot.@"allocator".

Implicit Types (m: gmap u64 ()) (free: gset u64).

Theorem wp_FreeRange (start sz: u64) :
  int.val start + int.val sz < 2^64 ->
  {{{ True }}}
    FreeRange #start #sz
  {{{ (mref: loc) m, RET #mref;
      is_map mref m ∗
      ⌜∀ (x:u64), int.val start ≤ int.val x < int.val start + int.val sz ->
                  m !! x = Some tt⌝ }}}.
Proof.
  iIntros (Hbound Φ) "_ HΦ".
  wp_call.
  wp_apply (wp_NewMap () (t:=struct.t unit.S)).
  iIntros (mref) "Hmap".
  wp_apply wp_ref_to; first by val_ty.
  iIntros (il) "i".
  wp_pures.
  wp_apply (wp_forUpto (λ i, ∃ m, "Hmap" ∷ is_map mref m ∗
      "%Hmap_vals" ∷ ⌜∀ (x:u64), int.val start ≤ int.val x < int.val i ->
                      m !! x = Some tt⌝)%I
            with "[] [Hmap $i]").
  - word.
  - clear Φ.
    iIntros (i).
    iIntros "!>" (Φ) "(HI & i & %Hibound) HΦ"; iNamed "HI".
    wp_pures.
    wp_load.
    wp_apply (wp_MapInsert _ _ _ _ () with "Hmap"); auto.
    iIntros "Hm".
    wp_pures.
    iApply "HΦ".
    iFrame.
    iExists _; iFrame.
    iPureIntro.
    replace (int.val (word.add i 1)) with (int.val i + 1) by word.
    intros x Hxbound.
    destruct (decide (x = i)); subst.
    + rewrite lookup_insert //.
    + rewrite lookup_insert_ne //.
      apply Hmap_vals.
      assert (int.val x ≠ int.val i) by (apply not_inj; auto).
      word.
  - iExists _; iFrame.
    iPureIntro.
    intros x Hxbound.
    word.
  - iIntros "[HI i]"; iNamed "HI".
    wp_pures.
    iApply "HΦ"; iFrame.
    iPureIntro.
    intros.
    apply Hmap_vals.
    word.
Qed.

Lemma big_sepM_lookup_unit (PROP:bi) `{Countable K}
  `{BiAffine PROP} (m: gmap K ()) :
  ⊢@{PROP} [∗ map] k↦_ ∈ m, ⌜m !! k = Some tt⌝.
Proof.
  iDestruct (big_sepM_lookup_holds m) as "Hmap".
  iApply (big_sepM_mono with "Hmap"); simpl; intros.
  destruct x; auto.
Qed.

(* this is superceded by wp_findKey, but that theorem relies in an unproven map
iteration theorem *)
Theorem wp_findKey' mref m :
  {{{ is_map mref m }}}
    findKey #mref
  {{{ (k: u64) (ok: bool), RET (#k, #ok);
      ⌜if ok then m !! k = Some tt else True⌝ ∗ (* TODO: easier if this
      promises to find a key if it exists *)
      is_map mref m
  }}}.
Proof.
  iIntros (Φ) "Hmap HΦ".
  wp_call.
  wp_apply wp_ref_to; first by val_ty.
  iIntros (found_l) "found".
  wp_apply wp_ref_to; first by val_ty.
  iIntros (ok_l) "ok".
  wp_pures.
  wp_apply (wp_MapIter _ _ _ _
                       (∃ (found: u64) (ok: bool),
                           "found" ∷ found_l ↦[uint64T] #found ∗
                           "ok" ∷ ok_l ↦[boolT] #ok ∗
                           "%Hfound_is" ∷ ⌜if ok then m !! found = Some tt else True⌝)
                       (λ k _, ⌜m !! k = Some tt⌝)%I
                       (λ _ _, True)%I
                       with "Hmap [found ok]").
  - iExists _, _; iFrame.
  - iApply big_sepM_lookup_unit.
  - iIntros (k v) "!>".
    clear Φ.
    iIntros (Φ) "[HI %Helem] HΦ"; iNamed "HI".
    wp_pures.
    wp_load.
    wp_pures.
    wp_if_destruct.
    + wp_store. wp_store.
      iApply "HΦ".
      iSplitL; auto.
      iExists _, _; iFrame.
      auto.
    + iApply "HΦ".
      iSplitL; auto.
      iExists _, _; iFrame.
      apply negb_false_iff in Heqb; subst.
      auto.
  - iIntros "(His_map&HI&_HQ)"; iNamed "HI".
    wp_pures.
    wp_load. wp_load.
    wp_pures.
    iApply "HΦ"; iFrame.
    auto.
Qed.

Theorem wp_findKey mref m :
  {{{ is_map mref m }}}
    findKey #mref
  {{{ (k: u64) (ok: bool), RET (#k, #ok);
      ⌜if ok then m !! k = Some tt else m = ∅⌝ ∗
      is_map mref m
  }}}.
Proof.
  iIntros (Φ) "Hmap HΦ".
  wp_call.
  wp_apply wp_ref_to; first by val_ty.
  iIntros (found_l) "found".
  wp_apply wp_ref_to; first by val_ty.
  iIntros (ok_l) "ok".
  wp_pures.
  wp_apply (wp_MapIter_fold _ _ (λ mdone, ∃ (found: u64) (ok: bool),
                           "found" ∷ found_l ↦[uint64T] #found ∗
                           "ok" ∷ ok_l ↦[boolT] #ok ∗
                           "%Hfound_is" ∷ ⌜if ok then m !! found = Some tt else mdone = ∅⌝)%I
           with "Hmap [found ok]").
  - iExists _, _; by iFrame.
  - clear Φ.
    iIntros (mdone k v) "!>".
    iIntros (Φ) "(HI&(%&%)) HΦ"; iNamed "HI".
    wp_pures.
    wp_load.
    wp_pures.
    wp_if_destruct;
      (* TODO: automate this in wp_if_destruct *)
      [ apply negb_true_iff in Heqb | apply negb_false_iff in Heqb ]; subst.
    + wp_store. wp_store.
      iApply "HΦ".
      iExists _, _; iFrame.
      destruct v; auto.
    + iApply "HΦ".
      iExists _, _; iFrame.
      auto.
  - iIntros "[Hm HI]"; iNamed "HI".
    wp_load. wp_load.
    wp_pures.
    iApply "HΦ".
    iFrame.
    destruct ok; auto.
Qed.

Implicit Types (P: alloc.t → iProp Σ).
Implicit Types (l:loc) (γ:gname) (σ: alloc.t).

Definition allocator_linv (mref: loc) σ : iProp Σ :=
  ∃ m, "Hfreemap" ∷ is_map mref m ∗
       "%Hfreeset" ∷ ⌜dom (gset _) m = σ.(alloc.free)⌝ ∗
       "Hblocks" ∷ [∗ set] k ∈ σ.(alloc.free), ∃ b, int.val k d↦ b
.

Definition allocator_durable σ : iProp Σ :=
  ([∗ set] k ∈ σ.(alloc.free), ∃ b, int.val k d↦ b)%I.

Definition is_allocator P (l: loc) (γ: gname) : iProp Σ :=
  ∃ (lref mref: loc),
    "#m" ∷ readonly (l ↦[Allocator.S :: "m"] #lref) ∗
    "#free" ∷ readonly (l ↦[Allocator.S :: "free"] #mref) ∗
    "#His_lock" ∷ is_lock allocN γ #lref (∃ σ, "Hlockinv" ∷ allocator_linv mref σ ∗ "HP" ∷ P σ)
.

Instance allocator_post_crash mref σ :
  IntoCrash (allocator_linv mref σ) (λ _, allocator_durable σ).
Proof.
  hnf; iIntros "H"; iNamed "H".
  by iFrame.
Qed.

Global Instance is_allocator_Persistent P l γ :
  Persistent (is_allocator P l γ).
Proof. apply _. Qed.

Theorem allocator_durable_from_map m :
  ([∗ map] a↦_ ∈ m, ∃ b, int.val a d↦ b) -∗
  allocator_durable (alloc.mk (dom (gset _) m)).
Proof.
  iIntros "Hblocks".
  iApply (big_sepM_dom with "Hblocks").
Qed.

Theorem wp_newAllocator P mref m σ :
  dom (gset _) m = σ.(alloc.free) ->
  {{{ is_map mref m ∗ allocator_durable σ ∗ P σ }}}
    New #mref
  {{{ l γ, RET #l; is_allocator P l γ }}}.
Proof.
  iIntros (Hfree Φ) "(Hmap&Hblocks&HP) HΦ".
  wp_call.
  wp_apply wp_new_free_lock.
  iIntros (γ lk) "Hlock".
  rewrite -wp_fupd.
  wp_apply wp_allocStruct; auto.
  iIntros (l) "Hallocator".
  iDestruct (struct_fields_split with "Hallocator") as "(m&free&_)".
  iMod (readonly_alloc_1 with "m") as "#m".
  iMod (readonly_alloc_1 with "free") as "#free".
  iMod (alloc_lock allocN ⊤ _ _
                   (∃ σ, "Hlockinv" ∷ allocator_linv mref σ ∗ "HP" ∷ P σ)%I
          with "[$Hlock] [-HΦ]") as "#Hlock".
  { iExists _; iFrame.
    iExists _; simpl; iFrame.
    auto. }
  iModIntro.
  iApply "HΦ".
  iExists _, _; iFrame "#".
Qed.

Lemma map_empty_difference `{Countable K} {V} (m: gmap K V) :
  ∅ ∖ m = ∅.
Proof.
  apply map_eq; intros.
  rewrite lookup_difference_None; eauto.
Qed.

Lemma set_empty_difference `{Countable K} (m: gset K) :
  ∅ ∖ m = ∅.
Proof.
  apply gset_eq; intros.
  rewrite elem_of_difference.
  intuition auto.
  apply not_elem_of_empty in H0; auto.
Qed.

Theorem wp_Reserve P (Q: option u64 → iProp Σ) l γ :
  {{{ is_allocator P l γ ∗
     (∀ σ σ' ma,
          ⌜match ma with
           | Some a => a ∈ σ.(alloc.free) ∧ σ' = set alloc.free (λ free, free ∖ {[a]}) σ
           | None => σ' = σ
           end⌝ -∗
          P σ ={⊤}=∗ P σ' ∗ Q ma)
  }}}
    Allocator__Reserve #l
  {{{ a (ok: bool), RET (#a, #ok);
      if ok then Q (Some a) ∗ (∃ b, int.val a d↦ b)
      else Q None }}}.
Proof.
  iIntros (Φ) "(Hinv&Hfupd) HΦ"; iNamed "Hinv".
  wp_call.
  wp_loadField.
  wp_apply (acquire_spec with "His_lock").
  iIntros "(His_locked & Hinner)"; iNamed "Hinner".
  iNamed "Hlockinv".
  wp_loadField.
  wp_apply (wp_findKey with "Hfreemap").
  iIntros (k ok) "[%Hk Hfreemap]".
  wp_pures.
  wp_loadField.
  wp_apply (wp_MapDelete with "Hfreemap"); iIntros "Hfreemap".
  iMod ("Hfupd" $! _ (if ok then _ else _) (if ok then Some k else None) with "[] HP") as "[HP HQ]".
  { destruct ok; simpl; auto.
    iPureIntro.
    split; auto.
    rewrite -Hfreeset.
    apply (elem_of_dom (D:=gset _)); eauto.  }
  wp_loadField.

  (* extract block, if ok *)
  iAssert (([∗ set] k0 ∈ if ok then σ.(alloc.free) ∖ {[k]} else σ.(alloc.free), ∃ b, int.val k0 d↦ b) ∗
          if ok then (∃ b, int.val k d↦ b) else emp)%I
          with "[Hblocks]" as "[Hblocks Hbk]".
  { destruct ok.
    - iDestruct (big_sepS_delete with "Hblocks") as "[$ $]".
      rewrite -Hfreeset.
      apply elem_of_dom; eauto.
    - iFrame. }

  wp_apply (release_spec with "[-HΦ HQ Hbk $His_lock $His_locked]").
  { iExists _; iFrame.
    iExists _; iFrame.
    iSplitR.
    - rewrite /map_del dom_delete_L.
      iPureIntro.
      destruct ok; simpl; try congruence.
      subst.
      rewrite -Hfreeset.
      rewrite !dom_empty_L.
      apply set_empty_difference.
    - destruct ok; iFrame. }

  wp_pures.
  iApply "HΦ".
  destruct ok; iFrame.
Qed.

End goose.
