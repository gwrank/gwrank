# Character Claim Flow Fixes

## Context

The character claim system allows players to claim characters by their in-game name (igname). When a character is already claimed by another player, a `CharacterClaim` record should be created for moderation. Currently, the `Profiles::CharactersController` silently fails when a character is already claimed, instead of creating a claim like the `OnboardingController` does.

Additionally, the `CharacterClaim.approve!` method has potential edge cases around character ownership conflicts.

## Problem Areas

### 1. Profiles::CharactersController#create (app/controllers/profiles/characters_controller.rb:11-44)
Current behavior:
```ruby
if @character.player_id.present?
  @professions = Profession.all
  render :new  # Just re-renders the form, no feedback to user
```

This silently fails - the user has no indication why their character wasn't added.

### 2. CharacterClaim.approve! (app/models/character_claim.rb:44-56)
```ruby
def approve!
  return unless pending?
  character.update(player: player) if character.player_id.nil?  # Only links if unowned
  ...
end
```

Edge cases:
- What if the character was claimed by another player between claim creation and admin approval?
- The `claimed_by` field is set but never used - it should track who initiated the claim
- The logic should handle conflicts where the character owner differs from the claimant

## Implementation Plan

### Task 1: Fix Profiles::CharactersController#create

When a character exists and is already claimed:
1. Create a pending `CharacterClaim` (same logic as `OnboardingController`)
2. Check for existing pending claim to avoid duplicates
3. Show flash message to user explaining the claim is pending approval
4. Redirect to profile edit page

Also update the view to handle flash messages properly.

### Task 2: Enhance CharacterClaim.approve!

Add logic to:
1. Handle the case where `character.player_id` is set but equals the claimant's player_id (same player, different account perhaps)
2. Handle the case where `character.player_id` is set to a different player - in this case, either:
   - Reject the approval (safe approach), OR
   - Update `claimed_by` field to track who claimed vs who owns the character

Based on the schema and existing logic, I'll implement:
- If character is unclaimed → assign to claimant
- If character is claimed by the same player who made the claim → already linked, just approve
- If character is claimed by a different player → reject with explanation (protects against race conditions)

### Task 3: Update Character model

Add a helper method to check if a character is claimable by a specific player:
```ruby
def claimable_by?(player)
  player_id.nil? || player_id == player.id
end
```

## Critical Files

- `app/controllers/profiles/characters_controller.rb` - Fix the create action
- `app/models/character_claim.rb` - Enhance approve! logic
- `app/models/character.rb` - Add claimable_by? helper
- `app/views/profiles/characters/new.html.erb` - Add flash message display
- `app/views/profiles/edit.html.erb` - Ensure flash messages are shown

## Verification Steps

1. **Test claim flow from profile**:
   - As Player A, create a character
   - As Player B, try to claim the same character via profile
   - Verify: CharacterClaim is created, Player B sees "pending approval" message

2. **Test admin approval**:
   - Admin approves a claim for an unowned character
   - Verify: Character.player_id is set to claimant, claim status is "approved"

3. **Test admin approval conflict**:
   - Admin tries to approve a claim where character is now owned by someone else
   - Verify: Claim is rejected or appropriately handled

4. **Test duplicate claim prevention**:
   - Player tries to claim same character twice
   - Verify: No duplicate pending claims created
