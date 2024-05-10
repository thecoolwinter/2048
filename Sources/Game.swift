import ArgumentParser
#if os(Linux)
import Glibc.ncurses
#else
import Darwin.ncurses
#endif

@main
struct Game: ParsableCommand {
    // MARK: - Options

    @Option(name: .shortAndLong, parsing: .next, help: "The number of levels to search.")
    var depthLimit: Int = 5

    @Flag(name: .customLong("no-human"), help: "Don't offer a human game (AI will play faster)")
    var noHuman: Bool = false

    @Flag(name: .long, help: "Hide the nice GUI, print boards to the terminal.")
    var hideGui: Bool = false

    @Flag(name: .shortAndLong, help: "Run a game and only output the final score.")
    var rawOut: Bool = false

    @Option(parsing: .remaining)
    var weights: [Float] = []

    // MARK: - Run

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    mutating func run() throws {
        var algGame = State()
        var humanGame = State()

        let algBoardIndex = noHuman ? 0 : 1
        var hasAlgGameEnded = false

        var player = Expectimax(depthLimit: depthLimit)
        var lastHumanMove: Move = .left

        if !weights.isEmpty {
            guard weights.count == 7 else {
                print("Invalid weight count")
                exit()
            }
            player.weights = weights
        }

        if rawOut {
            runOut()
        }

        if hideGui {
            noHuman = true
        }

        setUpSignals() // Init signal handler
        initNCurses()  // Init ncurses

        // Display the initial board(s)

        if !hideGui {
            clear()
        }
        if !noHuman {
            prettyDisplayBoard(humanGame.currentBoard, boardOffset: 0)
            displayBoardInfo(humanGame.currentBoard, step: humanGame.step, action: .left, boardOffset: 0)
        }
        prettyDisplayBoard(algGame.currentBoard, boardOffset: algBoardIndex)
        displayBoardInfo(algGame.currentBoard, step: algGame.step, action: .left, boardOffset: algBoardIndex)
        if !hideGui {
            refresh()
        }

        // Game loop
        // - Grab move(s)
        // - Display board(s)
        // - Check for terminal state, if true, wait for input to exit.
        while true {
            var algMove: Move = .left
            var humanMove: Move?
            if !hasAlgGameEnded {
                algMove = player.chooseMove(game: algGame)
                algGame.move(algMove)
            }

            if !noHuman {
                humanMove = getUserInput()
            }

            if !hideGui {
                clear()
            }
            prettyDisplayBoard(algGame.currentBoard, boardOffset: algBoardIndex)
            displayBoardInfo(algGame.currentBoard, step: algGame.step, action: algMove, boardOffset: algBoardIndex)

            if hasAlgGameEnded || algGame.terminalTest() {
                displayBoardInfo(
                    algGame.currentBoard,
                    step: algGame.step,
                    action: algMove,
                    isTerminal: true,
                    boardOffset: algBoardIndex
                )
                if noHuman {
                    waitForExit()
                }
                hasAlgGameEnded = true
            }

            if !noHuman {
                if let humanMove, humanGame.currentBoard.availableMoves().contains(humanMove) {
                    humanGame.move(humanMove)
                    lastHumanMove = humanMove
                }

                prettyDisplayBoard(humanGame.currentBoard, boardOffset: 0)
                displayBoardInfo(humanGame.currentBoard, step: humanGame.step, action: lastHumanMove, boardOffset: 0)

                if humanGame.terminalTest() {
                    displayBoardInfo(
                        humanGame.currentBoard,
                        step: humanGame.step,
                        action: lastHumanMove,
                        isTerminal: true,
                        boardOffset: 0
                    )
                    waitForExit()
                }
            }

            if !hideGui {
                refresh()
            }
        }
    }

    private func runOut() -> Never {
        var game = State()
        var player = Expectimax(depthLimit: depthLimit)
        while true {
            let move = player.chooseMove(game: game)
            game.move(move)
            if game.terminalTest() {
                break
            }
        }
        print(game.currentBoard.score)
        Self.exit(withError: ExitCode(0))
    }

    // MARK: - GUI

    private func prettyDisplayBoard(_ board: Board, boardOffset: Int) {
        guard !hideGui && has_colors() else {
            board.display(showHex: false)
            return
        }

        for row in 0..<4 {
            for col in 0..<4 {
                // Display the tile

                let value = board[row, col]
                // Top-left corner
                let minLine = LINES - Int32((4 - row) * 3) - 2
                let minCol = Int32((col * 7) + (boardOffset * 32) + 1)

                // Fill in empty lines, leave out padding space to the left and bottom.
                TileColor.setColor(forTile: value)
                move(minLine, minCol)
                out(String(repeating: " ", count: 7))

                move(minLine + 1, minCol)
                let str = String(value == 0 ? 0 : pow(2, value))
                out(" " + str + String(repeatElement(" ", count: 6 - str.count)))

                move(minLine + 2, minCol)
                out(String(repeating: " ", count: 7))
                TileColor.unsetColor(forTile: value)
            }
        }

        move(LINES - 1, 0)
    }

    private func displayBoardInfo(_ board: Board, step: Int, action: Move, isTerminal: Bool = false, boardOffset: Int) {
        if !hideGui {
            attron(COLOR_PAIR(0))
        }

        let col = 1 + Int32(boardOffset << 5)
        // The bottom line we can use. Increment down from here.
        var line = LINES - 15
        if !hideGui {
            move(line, col)
            line -= 1
        }

        // Step line
        out("Step    : \(step)")
        if !hideGui {
            move(line, col)
            line -= 1
        }

        // Move line
        out("Move    : \(action)")
        if !hideGui {
            move(line, col)
            line -= 1
        }

        // Step line
        out("Eval    : \(Expectimax(depthLimit: depthLimit).eval(board))")
        if !hideGui {
            move(line, col)
            line -= 1
        }

        // Score line
        out("Score   : \(board.score)")
        if !hideGui {
            move(line, col)
            line -= 1
        }

        // Game over?
        if isTerminal {
            out("GAME OVER")
        }

        if !hideGui {
            attroff(COLOR_PAIR(0))
            move(LINES - 1, 0)
        }
    }

    private func out(_ string: String) {
        guard !hideGui else {
            print(string)
            return
        }
        _ = string.withCString { ptr in
            addstr(ptr)
        }
    }

    // MARK: - ncurses

    private func initNCurses() {
        guard !hideGui else { return }

        initscr()            // Start curses mode
        raw()                // Raw input (no buffering, for arrow input)
        keypad(stdscr, true) // Enable getting keys
        noecho()             // Don't print user input to the terminal
        halfdelay(1)         // Wait 1/10 of a second for input

        if has_colors() {
            start_color()
            guard COLORS >= 13 else {
                return
            }

            init_color(0, 0x0, 0x0, 0x0)    // white
            init_color(1, 1000, 1000, 1000) // black
            init_pair(1, 0, 1)              // Pair 0 is black text w/ white bg.
            bkgdset(UInt32(COLOR_PAIR(1)))  // Set background
        }

        clear()   // Clean slate
        refresh()
    }

    // MARK: - User Input

    private func getUserInput() -> Move? {
        guard !hideGui else { return nil }

        let userInput = getch()
        guard userInput != ERR else {
            return nil
        }
        switch userInput {
        case 76, 108, KEY_LEFT:  // "L", "l", "⬅️"
            return .left
        case 82, 114, KEY_RIGHT: // "R", "r", "➡️"
            return .right
        case 68, 100, KEY_DOWN:  // "D", "d", "⬇️"
            return .down
        case 85, 117, KEY_UP:    // "U", "u", "⬆️"
            return .up
        case 81, 113:            // "Q", "q"
            exit()
        default: // ?????
            return nil
        }
    }

    // MARK: - Exit

    private func waitForExit() {
        guard !hideGui else { Self.exit(withError: ExitCode(0)) }

        move(LINES - 1, 0)
        out("Press any key to exit...")
        while true {
            if getUserInput() != nil {
                exit()
            }
        }
    }

    private func exit() -> Never {
        endwin()
        Self.exit(withError: ExitCode(0))
    }

    // MARK: - Signals

    /// Sets up signal handlers to gracefully shut down on a `ctrl-c` signal.
    private func setUpSignals() {
        guard !hideGui else { return }
        // Exit gracefully on SIGINT
        signal(SIGINT) { _ in
            endwin()
            Game.exit(withError: ExitCode(0))
        }
    }
}
