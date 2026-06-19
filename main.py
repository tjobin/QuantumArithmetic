from toffoli_estimator import estimate_multiplier
from plot import plot_multiplier_scaling
import qsharp

qsharp.init(project_root=".") 


n_vals = list(range(2, 10))
naive_t_counts = [estimate_multiplier("Naive", n) for n in n_vals]
addsub_t_counts = [estimate_multiplier("AddSubtract", n) for n in n_vals]

plot_multiplier_scaling(n_vals, naive_t_counts, addsub_t_counts, t_to_toffoli_ratio=4)