from toffoli_estimator import estimate_multiplier
from plot import plot_multiplier_scaling
import qsharp

qsharp.init(project_root=".") 


n_vals = list(range(2, 10))

addsub_toffoli_counts = [estimate_multiplier(n) for n in n_vals]

plot_multiplier_scaling(n_vals, addsub_toffoli_counts)