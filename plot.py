import matplotlib.pyplot as plt
import numpy as np

def plot_multiplier_scaling(n_values, empirical_t_naive, empirical_t_add_sub, t_to_toffoli_ratio=4):
    """
    Plots empirical T-counts (converted to Toffoli counts) against 
    theoretical Toffoli scaling bounds for quantum multiplication.
    """
    # Convert empirical T-counts to effective Toffoli counts
    emp_naive_toffoli = np.array(empirical_t_naive) / t_to_toffoli_ratio
    emp_addsub_toffoli = np.array(empirical_t_add_sub) / t_to_toffoli_ratio

    # Generate smooth x-values for theoretical curves
    n_continuous = np.linspace(min(n_values), max(n_values), 100)
    
    # Theoretical Toffoli count formulas from Litinski (2024)
    theory_naive = 2 * n_continuous**2 + n_continuous
    theory_add_sub = n_continuous**2 + 4 * n_continuous + 3

    plt.figure(figsize=(10, 6))

    # Plot theoretical predictions as smooth, dashed lines
    plt.plot(n_continuous, theory_naive, 
             label='Theory: Naive ($2n^2 + n$)', 
             color='#1f77b4', linestyle='--', zorder=1)
    
    plt.plot(n_continuous, theory_add_sub, 
             label='Theory: Add-Subtract ($n^2 + 4n + 3$)', 
             color='#ff7f0e', linestyle='--', zorder=1)

    # Plot empirical data as scatter points
    plt.scatter(n_values, emp_naive_toffoli, 
                label='Empirical: Naive', 
                color='#1f77b4', marker='o', s=60, zorder=2)
    
    plt.scatter(n_values, emp_addsub_toffoli, 
                label='Empirical: Add-Subtract', 
                color='#ff7f0e', marker='s', s=60, zorder=2)

    # Formatting and labels
    plt.title('Quantum Schoolbook Multiplication: Toffoli Count Scaling')
    plt.xlabel('Register Bit-width ($n$)')
    plt.ylabel('Equivalent Toffoli Count')
    plt.xticks(n_values)
    
    # Optional: Set y-axis strictly to integers if formatting gets messy
    # plt.gca().yaxis.set_major_locator(plt.MaxNLocator(integer=True))
    
    plt.grid(True, linestyle=':', alpha=0.7)
    plt.legend()
    plt.tight_layout()
    
    plt.show()

# --- Example Usage ---
# n_vals = [2, 3, 4, 5, 6, 7, 8, 9]
# naive_t_counts = [40, 84, 144, 220, 312, 420, 544, 684]       # Example mock data (T-counts)
# addsub_t_counts = [60, 96, 140, 192, 252, 320, 396, 480]      # Example mock data (T-counts)
# plot_multiplier_scaling(n_vals, naive_t_counts, addsub_t_counts, t_to_toffoli_ratio=4)