import cma
from multiprocessing import Pool
import subprocess


def play_score(weights, idx):
    weight_str = ""
    for weight in weights:
        weight_str += f" {weight}"
    game_out = subprocess.getoutput("./Game -d 3 -r --weights" + weight_str)
    return (int(game_out), idx)


if __name__ == "__main__":
    with Pool(processes=4) as pool:
        es = cma.CMAEvolutionStrategy(
            [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 2.0], 3.0
        )
        while not es.stop():
            new_weight_matr = es.ask()
            results = []
            scores = [0] * len(new_weight_matr)

            # Async send
            for i, new_weights in enumerate(new_weight_matr):
                for l in range(3):
                    results.append(pool.apply_async(play_score, (new_weights, i)))

            # Get the results
            for i in range(len(results)):
                (this_score, index) = results[i].get(timeout=None)
                scores[index] += 50000 - this_score

            # Compute the average for each
            for i in range(len(scores)):
                scores[i] /= 3

            es.tell(new_weight_matr, scores)
            es.logger.add()
            es.disp()
        es.result_pretty()
        cma.plot()
