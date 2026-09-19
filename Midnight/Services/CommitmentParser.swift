import Foundation

/// What the parser model extracts from "Tomorrow block TikTok until I do 2 LeetCode problems."
struct ParsedCommitment: Codable {
    var title: String
    var task_description: String
    var quantity: Int?
    var unit: String?
    var blocked_app_names: [String]
    /// 0 = today, 1 = tomorrow, etc.
    var activation_day_offset: Int
    /// "HH:mm" 24h local
    var activation_time: String
    var deadline_day_offset: Int
    var deadline_time: String
    var verification_method: String
    var penalty_release_time: String
    var clarifying_question: String?
}

enum CommitmentParser {
    static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["title", "task_description", "quantity", "unit", "blocked_app_names",
                     "activation_day_offset", "activation_time", "deadline_day_offset", "deadline_time",
                     "verification_method", "penalty_release_time", "clarifying_question"],
        "properties": [
            "title": ["type": "string", "description": "Short imperative title, e.g. 'Solve 2 LeetCode problems'"],
            "task_description": ["type": "string", "description": "What must be done, verb phrase, no app names"],
            "quantity": ["type": ["integer", "null"]],
            "unit": ["type": ["string", "null"], "description": "e.g. 'problems', 'miles', 'minutes'"],
            "blocked_app_names": ["type": "array", "items": ["type": "string"]],
            "activation_day_offset": ["type": "integer"],
            "activation_time": ["type": "string", "description": "HH:mm 24-hour"],
            "deadline_day_offset": ["type": "integer"],
            "deadline_time": ["type": "string", "description": "HH:mm 24-hour"],
            "verification_method": ["type": "string", "enum": ["screenshot", "photo", "manual"]],
            "penalty_release_time": ["type": "string", "description": "HH:mm 24-hour"],
            "clarifying_question": ["type": ["string", "null"],
                                    "description": "One short question if a required detail is missing, else null"]
        ]
    ]

    static func systemPrompt(now: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE yyyy-MM-dd HH:mm"
        return """
        You turn a late-night promise into a structured commitment for the Midnight app. \
        The user is motivated right now and wants their future self held to it.

        Current local time: \(f.string(from: now)).

        Rules:
        - "Tomorrow" means day offset 1. If it is after midnight and before 05:00 and the user says "tomorrow" \
        or "in the morning", they mean the coming morning: day offset 0.
        - If the user says "now", "right now", "starting now", "immediately", or "today" with no time: \
        activation_day_offset 0 and activation_time = the current local time shown above. This overrides every default.
        - Otherwise default activation is 07:00 on the target day. Activation must be in the future.
        - deadline_time defaults to "23:00" on the same day as activation (deadline_day_offset equal to activation_day_offset) \
        unless the user names a time like "before noon". The deadline must be after the activation time.
        - Default penalty_release_time is 19:00 (when apps unlock if they give up). Never earlier than the deadline's day start.
        - blocked_app_names: list every app, site, or category they mention blocking (e.g. "TikTok", "games", "social media"). \
        Empty if none.
        - verification_method: "screenshot" for digital work (coding, LeetCode, homework, submissions, Duolingo); \
        "photo" for physical tasks (gym, run, clean room, meal prep); "manual" only if nothing else fits.
        - quantity/unit: extract if present ("2 LeetCode problems" -> 2, "problems"; "run 3 miles" -> 3, "miles"; \
        "study 2 hours" -> 120, "minutes"). Null if absent.
        - clarifying_question: only when the task is too vague to verify (e.g. "run" with no distance or time). \
        Keep it under 12 words. Otherwise null.
        - title and task_description describe ONLY what the user must do. Never mention blocking, \
        apps, or restrictions in them. Those belong in blocked_app_names.

        Examples:
        Input: "Tomorrow, block TikTok, Instagram, and YouTube until I finish two LeetCode problems."
        title: "Solve 2 LeetCode problems", task_description: "solve two LeetCode problems", quantity: 2, \
        unit: "problems", blocked_app_names: ["TikTok", "Instagram", "YouTube"], verification_method: "screenshot"
        Input: "No Instagram tomorrow until I go to the gym."
        title: "Go to the gym", task_description: "go to the gym", quantity: null, unit: null, \
        blocked_app_names: ["Instagram"], verification_method: "photo"
        Input: "Right now, block Instagram until I do 10 pushups."  (current time 14:58)
        title: "Do 10 pushups", activation_day_offset: 0, activation_time: "14:58", deadline_day_offset: 0, \
        deadline_time: "23:00", quantity: 10, unit: "pushups", blocked_app_names: ["Instagram"], verification_method: "photo"
        Input: "Block games until I clean my room."
        title: "Clean my room", task_description: "clean my room", blocked_app_names: ["games"], \
        verification_method: "photo"

        Be decisive. Fill every field.
        """
    }

    static func parse(_ prompt: String, now: Date = Date()) async throws -> ParsedCommitment {
        let data = try await LLMClient.structured(
            model: LLMClient.parseModel,
            system: systemPrompt(now: now),
            userContent: [["type": "input_text", "text": prompt]],
            schemaName: "commitment",
            schema: schema,
            reasoningEffort: "minimal"
        )
        return try JSONDecoder().decode(ParsedCommitment.self, from: data)
    }

    /// Resolve the AI's day offsets and HH:mm strings into concrete dates.
    static func date(dayOffset: Int, hhmm: String, from now: Date, calendar: Calendar = .current) -> Date {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        let hour = parts.first ?? 7
        let minute = parts.count > 1 ? parts[1] : 0
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    /// Small models sometimes echo the whole sentence as the title. Strip the blocking clause.
    static func cleanTask(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for marker in ["until i ", "unless i ", "before i ", "until ", "unless "] {
            if let r = t.range(of: marker, options: .caseInsensitive) { t = String(t[r.upperBound...]); break }
        }
        for prefix in ["block ", "don't let me ", "dont let me ", "no ", "lock "] where t.lowercased().hasPrefix(prefix) {
            // Nothing after the blocking verb was a task; caller falls back to task_description.
            return ""
        }
        t = t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard let first = t.first else { return "" }
        return first.uppercased() + t.dropFirst()
    }

    static func build(from p: ParsedCommitment, prompt: String, now: Date = Date()) -> Commitment {
        let task = cleanTask(p.task_description).isEmpty ? cleanTask(p.title) : cleanTask(p.task_description)
        let title = cleanTask(p.title).isEmpty ? task : cleanTask(p.title)
        var activation = date(dayOffset: p.activation_day_offset, hhmm: p.activation_time, from: now)
        if activation < now.addingTimeInterval(60) { activation = now.addingTimeInterval(60) }
        var deadline = date(dayOffset: p.deadline_day_offset, hhmm: p.deadline_time, from: now)
        if deadline <= activation.addingTimeInterval(15 * 60) {
            // Model gave an unusable deadline; default to 23:00 on the activation day.
            let cal = Calendar.current
            deadline = cal.date(bySettingHour: 23, minute: 0, second: 0, of: activation) ?? activation.addingTimeInterval(8 * 3600)
            if deadline <= activation { deadline = activation.addingTimeInterval(4 * 3600) }
        }
        var penalty = date(dayOffset: p.activation_day_offset, hhmm: p.penalty_release_time, from: now)
        if penalty <= activation.addingTimeInterval(15 * 60) { penalty = deadline }

        return Commitment(
            prompt: prompt,
            title: title,
            taskDescription: task.isEmpty ? title : task,
            quantity: p.quantity,
            unit: p.unit,
            activationTime: activation,
            deadline: deadline,
            blockedApps: p.blocked_app_names,
            verification: VerificationMethod(rawValue: p.verification_method) ?? .manual,
            penaltyReleaseTime: penalty
        )
    }
}
