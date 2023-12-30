extension String {
    func inserting(separator: String, every: Int) -> String {
        var result: String = ""
        let characters = Array(self)
        stride(from: 0, to: characters.count, by: every).forEach {
            result += String(characters[$0..<min($0+every, characters.count)])
            if $0+every < characters.count {
                result += separator
            }
        }
        return result
    }
}
