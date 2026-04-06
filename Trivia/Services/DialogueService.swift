import Foundation

enum Dialogue {
    static func pick(_ arr: [String]) -> String {
        arr.randomElement() ?? ""
    }

    // MARK: - Briefing

    static func briefing(playerName: String?) -> String {
        let tod = timeOfDayFlavor()
        let greeting = playerName.map { "Hello \($0)!" } ?? "Hey there!"
        return tod.isEmpty ? greeting : "\(greeting) \(tod)"
    }

    private static func timeOfDayFlavor() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 6 {
            return pick(["Late night trivia? I respect the dedication.", "Can't sleep? Good, more trivia time.", "The best trivia happens after midnight."])
        }
        if h < 12 {
            return pick(["Hope you're having a great morning!", "Morning trivia — better than coffee.", "Rise and shine! Ready to win some points?"])
        }
        if h < 17 {
            return pick(["Hope you're having a lovely afternoon!", "Afternoon brain break? I like it.", "Perfect time to squeeze in a round."])
        }
        if h < 21 {
            return pick(["Hope you're having a great evening!", "Evening trivia session — solid choice.", "Nothing like an evening round to wrap up the day."])
        }
        return pick(["Hope you're having a good night!", "Late night trivia — solid move.", "Great way to end the day."])
    }

    static func firstQuestionIntro() -> String {
        "Let's play ToonTrivia!"
    }

    // MARK: - Question Formatting

    static func formatQuestion(_ question: Question, number: Int, prize: Int) -> String {
        let q = question.data
        let queryText = q.query ?? q.question ?? question.question ?? ""

        switch question.type {
        case .fourOptions:
            let raw = [q.optionA, q.optionB, q.optionC, q.optionD].compactMap { $0 }.filter { !$0.isEmpty }
            let optStr = raw.count > 1
                ? raw.dropLast().joined(separator: ", ") + ", or " + (raw.last ?? "")
                : raw.first ?? ""
            return "\(queryText) Is it \(optStr)?"

        case .whichIs:
            let o1 = q.option1 ?? q.optionA ?? ""
            let o2 = q.option2 ?? q.optionB ?? ""
            if !o1.isEmpty && !o2.isEmpty && !queryText.hasSuffix("?") {
                return "\(queryText) Is it \(o1), or \(o2)?"
            }
            return queryText

        case .beforeAfterBinary:
            return queryText

        case .oddOneOut:
            let opts = [q.option1 ?? q.optionA, q.option2 ?? q.optionB, q.option3 ?? q.optionC, q.option4 ?? q.optionD]
                .compactMap { $0 }.filter { !$0.isEmpty }
            let optStr = opts.count > 1
                ? opts.dropLast().joined(separator: ", ") + ", or " + (opts.last ?? "")
                : opts.first ?? ""
            return "Which of these is the odd one out? Is it \(optStr)?"

        case .fill4th:
            return queryText

        case .guessThePicture:
            let firstClue = question.hints?.first ?? question.data.clues?.first
            return firstClue.map { "Who is this? First clue: \($0)." } ?? "Take a look — who is this?"

        case .wipeout:
            return queryText

        case .beforeAfterChain:
            return queryText

        case .lightning:
            return "Lightning Round! Let's go!"

        case .hiddenTimer:
            return "Hidden Timer challenge! I'll say a number of seconds — buzz in when you think that much time has passed!"

        case .closestNumber:
            return queryText

        case .pictureChoice:
            return queryText
        }
    }

    // MARK: - Suspense

    static func suspense(selectedText: String, elapsed: Double?) -> String {
        var speedPrefix = ""
        if let elapsed, elapsed < 1.5 {
            speedPrefix = pick(["You clicked that fast— ", "That was instant— ", "No hesitation— "])
        }
        return speedPrefix + pick([
            "Let's see!", "Let's find out!", "Alright...",
            "Moment of truth!", "Here we go...", "And the answer is...",
        ])
    }

    // MARK: - Answer Reactions

    static func correct(playerName: String? = nil) -> String {
        let name = (playerName != nil && Double.random(in: 0...1) < 0.2) ? " \(playerName!)!" : "!"
        return pick(["That's right\(name)", "Correct\(name)", "You got it\(name)", "Well done\(name)",
                      "Excellent\(name)", "Spot on\(name)", "Nailed it\(name)"])
    }

    static func incorrect() -> String {
        pick(["Not quite!", "Oh, tough one!", "Unfortunately not!", "Ooh, that's wrong!",
              "Better luck next time!", "So close!"])
    }

    static func wrongAnswerEmpathy() -> String {
        pick(["That was a tough one!", "Ooh, close but not quite!", "That's a tricky one, don't worry!",
              "Ah, that one catches a lot of people!", "No worries, that was a hard one!"])
    }

    static func correctWithFact(_ fact: String) -> String {
        let reaction = correct()
        return fact.isEmpty ? reaction : "\(reaction) \(fact)"
    }

    static func incorrectWithFact(_ fact: String, correctAnswer: String) -> String {
        let reaction = incorrect()
        let correction = correctAnswer.isEmpty ? "" : "The correct answer was \(correctAnswer)."
        return [reaction, correction, fact].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - Transitions

    static func transitionToNext(totalWinnings: Int, nextPrize: Int, wasCorrect: Bool, roundEarnings: Int = 0, speedBon: Int = 0, streakBon: Int = 0) -> String {
        let p = formatMoney(nextPrize)

        var bonusParts: [String] = []
        if speedBon > 0 { bonusParts.append("speed bonus of \(formatMoney(speedBon))") }
        if streakBon > 0 { bonusParts.append("streak bonus of \(formatMoney(streakBon))") }
        let bonusLine = bonusParts.isEmpty ? "" : " Plus a \(bonusParts.joined(separator: " and a "))!"

        if !wasCorrect {
            if totalWinnings == 0 {
                return pick(["No worries! The next one is for \(p).", "Let's bounce back! Next up, \(p).",
                             "Moving on, this one's for \(p).", "Fresh start! This one is worth \(p)."])
            }
            let w = formatMoney(totalWinnings)
            return pick(["You're at \(w). This next one is for \(p).", "Still at \(w). Next one is worth \(p).",
                         "\(w) total. Moving on, this one's for \(p)."])
        }
        let r = formatMoney(roundEarnings)
        return pick(["You earned \(r) that round!\(bonusLine) This next one is for \(p).",
                      "\(r) earned!\(bonusLine) Next one is worth \(p).",
                      "Nice, \(r) won!\(bonusLine) Up next, \(p)."])
    }

    // MARK: - Lifelines

    static func fiftyFiftyAck() -> String {
        pick(["Two wrong answers removed! What's your answer now?",
              "50/50 it is! Two incorrect options removed.",
              "Good call! Narrowed it down for you."])
    }

    static func hintAck() -> String {
        pick(["Let me give you a hint...", "Here's a clue to help you out...",
              "A little help coming your way..."])
    }

    static func swapAck() -> String {
        pick(["Let's swap that question out for a new one...",
              "No problem! Here's a different question...",
              "Swap it is! Let me get you another question..."])
    }

    // MARK: - Game Complete

    static func gameComplete(wrongCount: Int) -> String {
        if wrongCount == 0 { return "A perfect game! Absolutely flawless — you got every single question right!" }
        if wrongCount == 1 { return "Almost perfect! Just one slip — that's an incredible performance!" }
        return "Well done! You made it through all 15 questions. That takes determination!"
    }
}

// MARK: - Helpers

func formatMoney(_ n: Int) -> String {
    "$\(n.formatted())"
}

func formatCompact(_ n: Int) -> String {
    if n == 0 { return "$0" }
    if n >= 1_000_000 {
        let v = Double(n) / 1_000_000
        return "$\(v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v))M"
    }
    if n >= 1_000 {
        let v = Double(n) / 1_000
        return "$\(v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v))K"
    }
    return "$\(n)"
}

func typeLabel(_ type: QuestionType) -> String {
    switch type {
    case .whichIs: return "Which Is?"
    case .beforeAfterBinary: return "Before or After?"
    case .fourOptions: return "Multiple Choice"
    case .fill4th: return "Fill the 4th"
    case .guessThePicture: return "Guess the Picture"
    case .oddOneOut: return "Odd One Out"
    case .wipeout: return "Wipeout"
    case .beforeAfterChain: return "Put in Order"
    case .lightning: return "Lightning Round"
    case .hiddenTimer: return "Hidden Timer"
    case .closestNumber: return "Closest Number"
    case .pictureChoice: return "Picture Choice"
    }
}
