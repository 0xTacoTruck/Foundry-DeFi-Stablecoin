# Foundry DeFi | Stablecoin Lesson Notes

### Lesson Overview

This lesson explores what DeFi is, applications and a bunch of other things. During this lesson we will cover:

- Creation of an ERC20 token that will represent the value of the US dollar - stablecoin
- 1 token will represent 1 US dollar
- Tokens are pegged and backed by US dollars
- System will always be "overcollateralised". At no point, should the value of all collateral < the $ backed value of all the tokens

The project will include source smart contracts for the DeFi system, deployment scripts for different chains, test suites for our smart contracts and scripts.

**_Note: The design of our DeFi system will be minimal in nature in comparison to large, real-world applications. This is an instructional lesson on the topic_**

## DeFi Overview

[DeFi Llama](https://defillama.com/) - website that gives insight into the world of DeFi.
[Maker DAO Forums](https://forum.makerdao.com/g) - Forums of the Maker DAO which is what this lesson's project is loosely based around

DeFi is such a broad area that it is difficult to provide all information you need to know. I can, however, provide some quick general statements about DeFi:

- DeFi is decentralised - with no reliance of 'trusting' intermediaries in traditional finance
- DeFi is programmatic. It allows scalability, automation and also removes those intermediaries
- DeFi is globally accessible to anyon with an internet connection. Breaking geograpchicaal barriers and underserved regions.
- DeFi on blockchain provides transaprency and immutability. Transactions and volumes can be verified in real-time.
- There is a large sense of familiarity of concepts between DeFi and traditional, centralised finance
- Exchanges, borrowing and lending, staking/locking of funds for periods of time all exist in DeFi
- Yield protocols of DeFi work similiar to passive income generation that is seen with bonds, interest savings account, stock dividends
- DeFi also includes protocls called Collateralized Debt Position (CDP). A CDP protocol allows users to lock up a certain amount of cryptocurrency as collateral to generate a loan in another cryptocurrency. An example is the MakerDAO system, users can lock up Ether (ETH) as collateral to generate DAI, a stablecoin pegged to the value of the US dollar. The locked-up ETH serves as collateral for the DAI loan, and users can later retrieve their collateral by repaying the borrowed DAI plus any accrued interest. There is no direct equivelance, but similarities can be found in: secured loans, margin trading, home equity lines of credit
- It also includes ver standard transacting use cases - like buying and selling things, not just digitalised things but also paying for real work objects/services

### Quick Section on Maximal Extractable Value (MEV)

[Flashbots](https://docs.flashbots.net/) - Wesbite aimed to reduce, prevent and remediate actions by bad actors looking to manipulate the blockchain for themselves.

Maximal Extractable Value (MEV) and MEV bots, is a topic we won't cover in this lesson but it becomes more and more important as we work through this lesson and continue to progress.

Blockchain validator nodes, when preparing block submissions, are able to order the transactions in such as way that a malicious actor can organise them in a manner that greatly benefits them - including stealing of funds.

## Introduction to Stablecoins

A stablecoin in the context of Web3 and decentralized finance (DeFi) refers to a type of cryptocurrency that is designed to maintain a stable value relative to a fiat currency or another asset. Stablecoins aim to mitigate the price volatility commonly associated with many cryptocurrencies like Bitcoin or Ethereum, making them more suitable for everyday transactions, smart contract executions, and as a store of value.

There are several mechanisms through which stablecoins achieve price stability:

1. Fiat-collateralized stablecoins: These stablecoins are backed by reserves of fiat currency (e.g., US dollars) held in a bank account or other custodial arrangement. Each stablecoin issued is backed by a corresponding amount of fiat currency held in reserve. Examples of fiat-collateralized stablecoins include Tether (USDT), USD Coin (USDC), and TrueUSD (TUSD).

2. Crypto-collateralized stablecoins: These stablecoins are backed by reserves of other cryptocurrencies, typically held in a smart contract. Users lock up cryptocurrencies like Ether (ETH) or Bitcoin (BTC) as collateral to generate stablecoin tokens. The value of the collateralized cryptocurrencies must exceed the value of the stablecoin tokens issued to maintain price stability. MakerDAO's DAI is an example of a crypto-collateralized stablecoin.

3. Algorithmic stablecoins: These stablecoins use algorithmic mechanisms to maintain price stability without explicit collateral backing. Algorithms adjust the stablecoin's supply based on supply-demand dynamics, aiming to keep the price pegged to a target value, such as $1. Examples include Terra's UST and Ampleforth (AMPL).

## Features of the stablecoin of this project

1. Relative Stability: Anchored or Pegged against $1 USD
   1. Will use Chainlink pricefeed
   2. Set a function to exchange ETH and BTC for what their equivelant $USD is
2. Stability Mechanism (Minting): Done Algorithmitically (Decentralised), 100% on-chain. No controlling entity.
   1. People can only mint the stablecoin when they have enough collateral (coded into smart contract)
3. Collateral Type: Exogenous (Crypto) - will use crypto as collateral. Accepting the following:
   1. ETH - the ERC20 version -> wETH (wrapped ETH)
   2. BTC - the ERC20 version -> wBTC (wrapped BTC)

## DecantralisedStableCoin.sol

The DecentralisedStableCoin.sol smart contract is this systems ERC20 token. It is minimalistic in contained functions because of the fact that we will have our 'engine' contract that will handle the bulk of our logic, and this token is simply utilised by the engine to achieve its requirements.

We utilise the Open Zeppelin contracts for the ERC20 structure, including its functions.

The only new programming syntax in this file is the use of the **'super'** keyword.

The super keyword allows us to tell our smart contract to refer to an inherrited file for that function/variable and not just this current contract.

## Planning Requirements for a Project - How using an Interface with the enginge contract can help

With projects, its important that we develop a list of requirements that need to be achieved. This will drive thinking about what functions are required for each requirement.

When it comes time for development, often developers will code an interface that can be inherrited by their core contract - in our case, the Decentralised Stable Coin Engine (DSCEngine.sol). The interface will contain a whole bunch of functions that the core contract needs, and acts as a tool to allow developers to be ware of what they need to code out in their core contract.

For this lesson's project, we are just going to have them written in the DSCEngine.sol file, in the DSCEngine contract.

## What is an overcollaterised system?

In an overcollateralized DeFi system, users can borrow funds by providing more collateral than the value of the loan they want to take. This excess collateral acts as a buffer to cover any potential fluctuations in the value of the assets being used as collateral. An overcollateralised system is where the value amount of collateral will **NEVER** be worth less than the valued amount of all the backed/pegged tokens.

For example, we deposit wETH as collateral that at the times was worth $60 dollars. For this, we recieved $40 worth of backed tokens. Then, the value of wETH plummits drastically to $10 dollars. This will cause drasatic instability in the valuation of the backed tokens as they are now not worth the orignal backed amount. An overcollateralised system prevents this from happening by ensuring that there is always more value in collateral than in the value of redeemed tokens/currency. This system will have precautions in place to liquidate, remove peoples positions, if they are nearing the point of having their collateral value threaten breaking the stability.

In these systems, there are often thresholds that are used to determine if actions is required to be taken to prevent instability of the backed tokens/currencies.

### Liquidating

Liquidation occurs when the value of the collateral falls below a certain threshold, typically determined by the protocol's rules. When this happens, the system automatically sells a portion of the collateral to repay the borrowed funds and any accrued interest. This ensures that the loan remains fully collateralized and reduces the risk for the lender.

Here's a simple analogy:

Imagine you borrow $100 from a friend, and you give them your watch as collateral, which is worth $200. This is overcollateralization because the value of your collateral ($200) is more than the value of the loan ($100). Now, if the value of the watch drops to $150, you might be in danger of defaulting on the loan because the collateral is no longer enough to cover the loan amount. In this case, your friend might decide to sell the watch to get their $100 back.

Similarly, in a DeFi system, if the value of your collateral drops below a certain threshold, the protocol may automatically sell a portion of your collateral to repay the loan. This is called liquidation.

The using of thresholds can also incentivise other accounts/individuals to liquidate others in bad positions to maintain stability, by offering rewards. For example:

An individual deposits $100 wETH as collateral and redeems $50 of a stable token. The protocol has a 25% threshold. The value of wETH drops to $74, this raises alerts for breaching the threshold of 25% and allows liquidation to occur. An individual covers the cost of the $50 of the token, while the original depositor has their amount reduced to zero. As a reward for ensuring stability and covering the cost of the $50 worth of the token, that individual is rewarded with the $74 worth of collateral that was put down. The token remains stable, the original depositor is not in debt, and whom it was that liquidated the depositor is rewarded for assisting the stability.

Liquidation helps maintain the stability and security of the DeFi system by ensuring that loans are adequately backed by collateral, even in volatile market conditions. It protects lenders from potential losses due to defaulting borrowers.

## Quick Section about nested mapping

```
mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
```

Here's what each part of the code means:

**_mapping_**: In Solidity, a mapping is a data structure similar to a hash table or dictionary in other programming languages. It maps keys to values and allows for efficient lookup and storage of data. In this case, the mapping is used to associate a user's address with another mapping.

_address user_: This is the key of the outer mapping. It represents the Ethereum address of a user who interacts with the smart contract. Each user's address will correspond to a separate inner mapping.

**_mapping(address token => uint256 amount)_**: This is the inner mapping. It associates ERC20 token addresses with the amount of that token deposited by the user. The key of this inner mapping is the address of the ERC20 token, and the value associated with each token address is the amount of that token deposited by the user.

_address token_: This represents the key of the inner mapping, which is the address of an ERC20 token.

_uint256 amount_: This represents the value associated with each token address in the inner mapping. It indicates the amount of the corresponding ERC20 token deposited by the user.

_private_: This keyword denotes that the mapping is only accessible within the current contract and cannot be accessed or modified from outside the contract.

So, in summary, this mapping is used to track the amount of each ERC20 token deposited by each user in a smart contract. It allows the contract to keep a record of the collateral deposited by users.

## Walkthrough of the Health Factor Rating & Associated Math Used in This Project

In this project, we use the ratio of collateral value a user has, against the number of minted DSC a user has to determine the health factor of the user.

To achieve this, we are required to decide what percentage minimum extra value a users collateral must be in order to keep the system in overcollateralisation. This percentage is normally quite a bit higher then the value of the collateral so that liquidation can occur before any negative consequences occur for our stablecoin and the system in general (we are pegging our token to the USD).

To ensure you understand what is happening in this process, we will walk through what is occuring in the project.

Firstly, this example assumes we have already got the total collateral value of a user in USD, and we also have the number of minted DSC a user has.

### Thresholds and Precision values

In this project, we use constant variables to store our projects threshold, and also the precision we want to employ for calculations.

```
 uint256 private constant PRECISION = 1e18;

//Liquidation threshold - used to determine when to liquidate a user so that we always remain overcollateralised. VIEW LIKE 50 OUT OF 100, OR 50%
uint256 private constant LIQUIDATION_THRESHOLD = 50; // means you need to be 200% overcollateralised

//Liquidiation precision - VIEW LIKE 100%, OR 100 OUR OF 100
uint256 private constant LIQUIDATION_PRECISION = 100;
```

As you can see in the comments, its easier to think of these values as a percentage out of 100.

**But what does the 50 in the LIQUIDATION_THRESHOLD variable actually mean?**

What this value means is that even if the value of the collateral drops by half, it still covers the DSC debt. Therefore, users need to maintain 200% collateralisation.

So if we imagine the whole collateral value is worth $200 USD, our code allows the user to have $100 USD worth of our USD pegged DSC tokens - meaning 100 DSC.
If the users collateral became volatile and decreasing in value, we allow the users total collateral value to drop by 50% before we liquidate - e.g. the users collateral is now worth $100 USD - the same as our DSC token, which threatens the pegging of our DSC to the USD if the price continues to fall, and will violate our overcollateralised system.

**What is the LIQUIDATION_PRECISION?**

The LIQUIDATION_PRECISION value represents the granularity of the liquidation threshold. A higher precision means the threshold is more finely divided, while a lower precision results in a coarser threshold.

The LIQUIDATION_PRECISION constant is used to divide the liquidation threshold value. When the precision is higher, the liquidation threshold value is divided into more parts, making the threshold stricter. This means that users need to maintain a higher level of collateral relative to their debt to avoid liquidation.

Conversely, when the precision is lower, the liquidation threshold value is divided into fewer parts, making the threshold more lenient. Users may need to maintain a lower level of collateral relative to their debt to avoid liquidation.

**Using the Threshold and Precision in Equation**

```
uint256 collateralAdjustedForThreshold =
            (totalCollateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        //Will be a very large number because of the exponent, but calling function can compare against 1e18 to determine if below minimum health score
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
```

Calculating these equations, we can generate a value that is 1e18 long. Which we can make easier for human readers by dividing by 1e18. Lets walk through an example using the constant variables from before:

```
 collateralAdjustedForThreshold = ($200 * 50) / 100 =  100

 Health Factor = (100 (from result above) * 1e18) => 100,000,000,000,000,000,000 (100e18) / 100 (total DSC minted by user) = 1,000,000,000,000,000,000 (1e18)

 Health Factor = 1,000,000,000,000,000,000 / 1e18 = 1
```

Our Project says that the MINIMUM health score we allow before liquidation is 1. Anything below the value of 1 will trigger liquidation. So the user in this first example is healthy.

Let's walk through another example:

```
collateralAdjustedForThreshold = ($175 * 50) / 100 = 87.5

Health Factor = (87.5 (from result above) * 1e18) => 87,500,000,000,000,000,000 (87.5e18) / 100 (total DSC minted by user) = 875,000,000,000,000,000

Health Factor = 875,000,000,000,000,000 / 1e18 = 0.875
```

This user is found to only have a health factor of 0.875, meaning its violated our over collaterisation threshold measures and this user can and will be liquidated!

## Testing while Developing Tip

After laying down some foundational logic, we want to begin to incorporate testing into our project lifecycle so that we are able to identify and rectify any problems earlier in the project lifecycle. We don't want to spend months or years working on a very large codebase without conducting periodic testing, only to have to re-enter a significant development cycle when we finally conduct thorough testing and uncover a number of issues. Sometimes the issues will affect other areas of your code that will then also require fixing!

A simple approach to use is:
1. Build out the rough layout of your code, using any design documents to aid in this.
2. Compile code to help identify any issues straight away (e.g. syntax violations, access modifiers, etc)
3. Begin to tackle one function, or one design requirement at a time. Break large requirements into smaller sections and work through those.
4. When you have built out some logic in functions, or abstract contracts, libraries, etc. Begin to write some unit tests for those pieces of logic. You may also need to work on creating deploy contracts, to be able to deploy the project code youre working on for testing. Your testing scope will also broaden to include interactions outside of your smart contracts!
5. Run tests, record results, rectify issues, run tests, record results, rectify issues.... Repeat until the issues are resolved and the code operates as expected and meets design, security, and compliance requirements.
6. Repeat steps 3-5 until development is complete

This is a very brief and high-level guide. There are many resources available that dive deeper into this topic, but I wanted to ensure that I included some brief guidance.