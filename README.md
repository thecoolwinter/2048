# 2048 Solver

Hi! Welcome to my weekend project, a [2048](https://play2048.co/) solver written in Swift. 

This project started as a final paper I turned in in December of 2023. The paper was written for an AI class (taught by the amazing [Dr. Andrew Exely](https://cse.umn.edu/cs/andrew-exley)), and explored the use of both the [Expectiminimax](https://en.wikipedia.org/wiki/Expectiminimax) and [Monte-Carlo Tree Search](https://en.wikipedia.org/wiki/Monte_Carlo_tree_search) to play the 2048 puzzle.

<details>
	<summary>⚠️ If you don't know what 2048 is ⚠️</summary>
	## 2048
	[2048](https://play2048.co/) is a web-based game released in 2014 by Gabriele Cirulli. The game consists of a 4x4 grid of tiles. Each tile has a value starting at 2, and can be combined with other tiles by sliding them together. The player plays the game by using the arrow keys to slide the tiles in each of the four directions to slide tiles together to create larger and larger tiles. However, each tile can only be combined with tiles of equal value. So, a 2 tile cannot merge with a 4 tile but a 2 tile can merge with another 2 tile to create a 4 tile.

	I'd highly suggest giving the game a go before reading on, it's extremely simple and fun and you'll get a better grip on it than reading this explanation.

</details>

This solver uses an Expectiminimax agent to search the 2048 game state graph to find an optimal move from any board position. It does so by maximizing the expected value of any move on any board, recursively for each move. To do this, an agent first makes a call to `Max`, which iterates through all available moves for a board and returns the maximum value possible. To decide which move yields the maximum value, it calls `Chance` which finds the expected value of the resulting board. 

The original implementation used Python, and represented the board using a 2D numpy array. This worked well, but only allowed us to search to depths of about 3-4 before the algorithm took too long to compute results. The primary reason for this, was latency in methods that needed to modify the board. Some examples are:

-   Performing a user action (Left, Right, Up, Down).
-   Rotate the board (only one direction is implemented, used rotate to perform it in different directions).
-   Checking for terminal state (requires: user action + rotate $\times$ 4).
-   Updating the board's tile values post-action.

All of these are really just simple array operations, but because they used Python there was a lot of added overhead. So, over the course of a couple afternoons I ported the code to Swift. This repository is the result of that project.

## Part 1: Board Representation

With Swift, I was able to create a board representation that had minimal overhead both in memory and number of instructions required to perform operations. The board is represented using a single 64-bit wide integer where every 4 bites (each nibble) represents a single tile. The value stored is the $2^x$ value of the tile, which is possible due to the fact that 2048's tile values are all powers of two (2, 4, 8, ...). The tiles are also stored in order from top-left going left-to-right down the board. Below is a quick example with rows, columns and tile indexes aligned with each nibble of the board.

```
Tile |  0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 |
Row  |  0                 | 1                 | 2                 | 3                 |
Col  |  0  | 1  | 2  | 3  | 0  | 1  | 2  | 3  | 0  | 1  | 2  | 3  | 0  | 1  | 2  | 3  |
Bits | 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
```

This representation is not new, and I have to give credit for the original idea to Rober Xaio's solution [here](https://stackoverflow.com/questions/22342854/what-is-the-optimal-algorithm-for-the-game-2048/22498940#22498940) and [here](https://github.com/nneonneo/2048-ai/tree/master). However, with knowledge of his solution I was curious if it was possible to speed it up further by reducing memory jumps and keeping board operations CPU-bound by not using lookup tables. The idea was that less memory movement would equal a faster algorithm. This turned out not to be true, and my implementation is orders of magnitude slower than Xaio's. Despite that, I'm making this project public in hopes someone finds it interesting.

Using the Int64 board representation, there are three simple operations that must be implemented for the game to be able to run: `right`, `rotate`, and row-col updates. For player actions, we only need a single direction implemented if we combine it with a rotate function. This means each direction becomes a combination of `rotate x times` ➡️ `right` ➡️ `rotate back around` so both the `rotate` and `right` functions must be fast.

The `rotate` function simply maps each tile to a single tile in a new board, performing a clockwise rotation like below.

```
8     128   2048  32768 
4     64    1024  16384 
2     32    512   8192  
0     16    256   4096  

`rotate()`

0     2     4     8     
16    32    64    128   
256   512   1024  2048  
4096  8192  16384 32768 
```

I was able to spot the correlation between the original row/col and resulting row/col by creating a map for each tile. The map contains the `(row, col)` pair for each tile in a board for a clockwise rotation.

```
(0, 3) (1, 3) (2, 3) (3, 3)
(0, 2) (1, 2) (2, 2) (3, 2)
(0, 1) (1, 1) (2, 1) (3, 1)
(0, 0) (1, 0) (2, 0) (3, 0)
```

Using this, the rotate function becomes quite simple, and we can just iterate through the board's nibbles and return a new board.

```swift
func rotateClockwise() -> Board {
    var result = Board(0, score: score) // Create a new board to return
    var board = self.board // Make a copy of the current board's representative Int
    var idx: UInt = 16 // Loop backwards from the bottom-right up
    while board > 0 {
        idx -= 1
        let row = idx >> 2 // idx / 4
        let col = idx & 3  // idx % 4
        result[col, 3 - row] = UInt(board & 0xF) // Grab only the last nibble
        board >>= 4 // Shift to get the next tile
    }
    return result
}
```

The rest of the board operations are similar, we make new board then iterate
