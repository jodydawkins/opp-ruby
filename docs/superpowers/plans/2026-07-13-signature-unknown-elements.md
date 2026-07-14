# Signature Unknown Elements Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align `OPP::Signature` tests with the protocol rule that unknown signature-object members may be ignored when string-valued `algorithm` and `value` members are present.

**Architecture:** Change only the existing signature unit spec. Separate required-member rejection from unknown-member acceptance so each protocol rule is explicit.

**Tech Stack:** Ruby 3.2+, RSpec 3.13

## Global Constraints

- Update tests only; do not change production behavior.
- Require string-valued, string-keyed `algorithm` and `value` members.
- Accept unknown members with string or symbol keys.

---

### Task 1: Align signature-object tests with extension handling

**Files:**
- Modify: `spec/opp/signature_spec.rb:58`
- Test: `spec/opp/signature_spec.rb`

**Interfaces:**
- Consumes: `OPP::Signature.sign(document, private_key:)` and `OPP::Signature.verify!(document, public_key:)`.
- Produces: Regression coverage for required signature members and ignored unknown members.

- [ ] **Step 1: Run the focused spec to demonstrate the stale expectation**

Run: `bundle exec rspec spec/opp/signature_spec.rb`

Expected: FAIL because the invalid-case loop expects an `InvalidSignatureError` for signatures containing only additional unknown members, while `verify!` accepts them.

- [ ] **Step 2: Focus the invalid table on required members**

Replace the existing exactly-two-members example and its invalid table with:

```ruby
it "requires string-valued algorithm and value members" do
  valid = described_class.sign(registration, private_key:)
  invalid_signatures = [
    nil,
    { "algorithm" => "ed25519" },
    { "algorithm" => "ed25519", "value" => 7 },
    { algorithm: "ed25519", value: valid.dig("signature", "value") }
  ]

  invalid_signatures.each do |signature|
    document = valid.merge("signature" => signature)
    expect { described_class.verify!(document, public_key:) }
      .to raise_error(OPP::InvalidSignatureError)
  end
end
```

- [ ] **Step 3: Add positive coverage for unknown members**

Immediately after the required-members example, add:

```ruby
it "ignores unknown signature members" do
  signed = described_class.sign(registration, private_key:)

  expect(
    described_class.verify!(
      signed.merge("signature" => signed["signature"].merge("extra" => true, extra: true)),
      public_key:
    )
  ).to be(true)
end
```

- [ ] **Step 4: Run the focused spec**

Run: `bundle exec rspec spec/opp/signature_spec.rb`

Expected: PASS with zero failures.

- [ ] **Step 5: Run the complete suite**

Run: `bundle exec rspec`

Expected: PASS with zero failures.

- [ ] **Step 6: Commit the test update**

```bash
git add spec/opp/signature_spec.rb
git commit -m "test: allow unknown signature members"
```
