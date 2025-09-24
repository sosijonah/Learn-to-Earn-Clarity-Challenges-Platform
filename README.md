# 🎓 Learn-to-Earn Clarity Challenges Platform

A decentralized platform for learning Clarity smart contract development through incentivized challenges! 🚀

## 📚 Overview

The Learn-to-Earn Clarity Challenges Platform enables developers to:
- Create and participate in coding challenges
- Earn STX rewards for successful submissions
- Build reputation in the Stacks ecosystem
- Contribute to developer education

## 🔑 Key Features

- Challenge creation with STX rewards
- Automated submission tracking
- DAO-based review system
- Reputation scoring
- Progressive difficulty levels

## 🛠 Contract Functions

### For Challenge Creators
- `create-challenge`: Create a new challenge with title, description, difficulty, and reward
- `add-reviewer`: Add authorized reviewers to the platform

### For Learners
- `submit-challenge`: Submit solution for a challenge
- `get-challenge`: View challenge details
- `get-user-profile`: Check user stats and reputation
- `get-submission`: View submission details

### For Reviewers
- `review-submission`: Review and approve/reject submissions
- `get-platform-stats`: View platform statistics

## 🚀 Getting Started

1. Deploy the contract using Clarinet
2. Initialize the contract using `initialize-contract`
3. Create challenges by calling `create-challenge`
4. Submit solutions using `submit-challenge`
5. Reviewers can evaluate submissions using `review-submission`

## 💡 Example Usage

```clarity
;; Create a challenge
(contract-call? .learn-to-earn create-challenge "Hello Clarity" "Write your first Clarity contract" u1 u1000)

;; Submit a solution
(contract-call? .learn-to-earn submit-challenge u1 "my-solution-code")

;; Review submission
(contract-call? .learn-to-earn review-submission u1 tx-sender true)
```

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📜 License

MIT
```
