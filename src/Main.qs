namespace QuantumArithmetic {
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Canon;

    /// # Summary
    /// In-place quantum ripple-carry adder based on Gidney's 2018 topology.
    /// Computes |a⟩|b⟩ ↦ |a⟩|a+b⟩ with a dedicated carry-out.
    /// 
    /// # Input
    /// * cin: The input carry qubit.
    /// * a: The first addend register (acts as control/temporary carry storage).
    /// * b: The second addend register (acts as the target accumulator).
    /// * cout: The output carry qubit.

    @EntryPoint()
    operation Main(): Result[] {
        // return GidneyAdderWithCarryOut_Example()
        // return GidneySubtracterWithCarryOut_Example();
        // return GidneySubtracterWithoutCarryOut_Example();
        // return NaiveMultiplication_Example();
        return AddSubtractMultiplication_Example();
    }
    
    // --- SUB-ROUTINES ---
    operation AddSubtractMultiplication(x: Qubit[], y: Qubit[], r: Qubit[]): Unit is Adj + Ctl {
        let n = Length(x);
        Fact(Length(r) == 2 * n + 1, "Result register 'r' must be exactly twice the length of 'x'.");
        // Allocate a clean carry-in for the main loop
        use cin = Qubit();

        for i in 0 .. n - 1 {
            let b = r[i .. i + n - 1];
            let cout = r[i + n];
            ControlledAddSubtract(x[i], cin, y, b, cout);
        }
        
        let r_upper = r[n .. 2 * n - 1];
        // Step 1: Add 2^n(x + 1)
        use cin_step1 = Qubit();
        X(cin_step1); 
        // We use the WithCarryOut variant and map the carry directly to r[2n]
        GidneyAdderWithCarryOut(cin_step1, x, r_upper, r[2 * n]);
        X(cin_step1);
        

        // Step 2: Subtract (2^{2n} + y)
        // We construct the exact subtrahend in a temporary 2n+1 qubit register
        use subtrahend = Qubit[2 * n + 1];
        // Copy y into the lowest n bits
        for i in 0 .. n - 1 {
            CNOT(y[i], subtrahend[i]); 
        }
        // Set the 2n-th bit to represent 2^{2n} - Now subtrahend is the exact binary 2^{2n} + y
        X(subtrahend[2 * n]); 

        // Perform the full-register subtraction in place
        use cin_step2 = Qubit();
        GidneySubtracterWithoutCarryOut(cin_step2, subtrahend, r);
        // Uncompute the subtrahend register to clean up the ancillas
        X(subtrahend[2 * n]);
        for i in 0 .. n - 1 {
            CNOT(y[i], subtrahend[i]); 
        }
        // Step 3: Add 2^n(y)
        use cin_step3 = Qubit();
        // Again, map the carry directly to r[2n] to ensure proper modular wrap-around
        GidneyAdderWithCarryOut(cin_step3, y, r_upper, r[2 * n]);

        // --- DIVISION BY TWO ---
        // The state of r is now exactly 2xy. 
        // r[0] is in the |0> state. 
        // The product xy is logically located at r[1 .. 2n].
    }

    operation NaiveMultiplication(x: Qubit[], y: Qubit[], r: Qubit[]): Unit is Adj + Ctl {
        let n = Length(x);
        // Ensure the result register can hold the maximum possible product
        Fact(Length(r) == 2 * n, "Result register 'r' must be exactly twice the length of 'x'.");

        use cin = Qubit();

        for i in 0 .. n - 1 {
            let b = r[i .. i + n - 1];
            let cout = r[i + n];
            Controlled GidneyAdderWithCarryOut([x[i]], (cin, y, b, cout));
        }
    }

    operation ControlledAddSubtract(control: Qubit, cin: Qubit, a: Qubit[], b: Qubit[], cout: Qubit) : Unit is Adj + Ctl {
        // 1. Invert the control to target the |0> state
        X(control);

        // 2. If the original control was |0>, prepare 'a' and 'cin' for subtraction
        Controlled X([control], cin);
        Controlled ApplyToEachCA([control], (X, a));

        // 3. Restore the control qubit to its true state
        X(control);

        // 4. Execute the UNCONTROLLED adder (Costs exactly n Toffolis)
        GidneyAdderWithCarryOut(cin, a, b, cout);

        // 5. Uncompute the subtraction preparation
        X(control);
        Controlled ApplyToEachCA([control], (X, a));
        Controlled X([control], cin);
        X(control);
    }

    operation GidneySubtracterWithoutCarryOut(cin: Qubit, a: Qubit[], b: Qubit[]) : Unit is Adj + Ctl {
        X(cin);
        ApplyToEachCA(X, a);
        GidneyAdderWithoutCarryOut(cin, a, b);
        ApplyToEachCA(X, a);
        X(cin);
    }

    operation GidneySubtracterWithCarryOut(cin: Qubit, a: Qubit[], b: Qubit[], cout: Qubit) : Unit is Adj + Ctl {
        X(cin);
        ApplyToEachCA(X, a);
        GidneyAdderWithCarryOut(cin, a, b, cout);
        ApplyToEachCA(X, a);
        X(cin);
    }

    operation GidneyAdderWithCarryOut(cin: Qubit, a: Qubit[], b: Qubit[], cout: Qubit) : Unit is Adj + Ctl {
        let n = Length(a);
        Fact(Length(b) == Length(a), "Result register 'a' must be exactly the length of 'b'.");
        
        if n > 0 {
            // Allocates exactly n-1 clean ancillas. 
            // Total qubits for n=5: 5(a) + 5(b) + 1(cin) + 1(cout) + 4(anc) = 16
            use anc = Qubit[n - 1];

            // --- Forward Sweep (Computing Carries) ---
            for i in 0 .. n - 1 {
                let cPrev = i == 0 ? cin | anc[i - 1];
                let cNext = i == n - 1 ? cout | anc[i];

                // 1. Copy the old carry into the clean ancilla wire
                
                // 2. Flip the inputs based on the old carry
                CNOT(cPrev, a[i]);
                CNOT(cPrev, b[i]);
                
                // 3. Toffoli computes the MAJ difference and adds it to the old carry.
                // Result: cNext now holds the TRUE absolute carry.
                CCNOT(a[i], b[i], cNext);
                CNOT(cPrev, cNext);
                // if i > 0 {
                //     CNOT(cPrev, cNext);
                // }
            }

            // --- Reverse Sweep (Uncomputation & Sum) ---
            for i in n - 1 .. -1 .. 0 {
                let cPrev = i == 0 ? cin | anc[i - 1];
                let cNext = i == n - 1 ? cout | anc[i];

                // 1. Uncompute the Toffoli (Skipped for the final preserved carry-out)
                if i < n - 1 {
                    CCNOT(a[i], b[i], cNext); 
                }

                // 2. Uncompute the CNOT to restore the 'a' register to its pristine state
                CNOT(cPrev, a[i]);

                // 3. Compute the final arithmetic sum bit into the 'b' register
                // (b[i] currently holds b_i ^ cPrev. Adding a_i completes the sum).
                CNOT(a[i], b[i]);

                // 4. Clean the ancilla back to |0> (Skipped for the final preserved carry-out)
                // 4. Clean the ancilla (Skipped for carry-out AND skipped for i=0)
                // if i > 0 and i < n - 1 {
                //     CNOT(cPrev, cNext);
                // }
                if i < n - 1 {
                    CNOT(cPrev, cNext);
                }
            }
        }
    }

    operation GidneyAdderWithoutCarryOut(cin: Qubit, a: Qubit[], b: Qubit[]) : Unit is Adj + Ctl {
        let n = Length(a);
        Fact(Length(b) == Length(a), "Result register 'a' must be exactly the length of 'b'.");

        
        if n > 0 {
            // Allocates exactly n-1 clean ancillas. 
            use anc = Qubit[n - 1];

            // --- Forward Sweep (Computing Carries) ---
            for i in 0 .. n - 1 {
                let cPrev = i == 0 ? cin | anc[i - 1];

                // 1. Flip the inputs based on the old carry
                CNOT(cPrev, a[i]);
                CNOT(cPrev, b[i]);
                
                // 2. Compute the carry for the next bit (Skipped for the final bit)
                if i < n - 1 {
                    let cNext = anc[i];
                    
                    // Toffoli computes the MAJ difference and adds it to the old carry.
                    CCNOT(a[i], b[i], cNext);
                    // if i > 0 {
                    //     CNOT(cPrev, cNext);
                    // }
                    CNOT(cPrev, cNext)
                }
            }

            // --- Reverse Sweep (Uncomputation & Sum) ---
            for i in n - 1 .. -1 .. 0 {
                let cPrev = i == 0 ? cin | anc[i - 1];

                // 1. Uncompute the Toffoli (Skipped for the final bit)
                if i < n - 1 {
                    let cNext = anc[i];
                    CCNOT(a[i], b[i], cNext); 
                }

                // 2. Uncompute the CNOT to restore the 'a' register to its pristine state
                CNOT(cPrev, a[i]);

                // 3. Compute the final arithmetic sum bit into the 'b' register
                CNOT(a[i], b[i]);

                // 4. Clean the ancilla (Skipped for the final bit AND skipped for i=0)
                // if i > 0 and i < n - 1 {
                //     let cNext = anc[i];
                //     CNOT(cPrev, cNext);
                // }
                if i < n - 1 {
                    let cNext = anc[i];
                    CNOT(cPrev, cNext);
                }
            }
        }
    }

    // --- EXAMPLE OF APPLICATIONS --- 

    operation AddSubtractMultiplication_Example(): Result[] {
        let n = 3;
        use x = Qubit[n];
        use y = Qubit[n];
        use r = Qubit[2*n + 1];

        // 1. Prepare states
        // Set a = 3 (binary 011 -> a[0]=1, a[1]=1, a[2]=0)
        X(x[0]); 
        X(x[1]);
        X(x[2]);
        //
        // Set b = 2 (binary 010 -> b[0]=0, b[1]=1, b[2]=0)
        X(y[0]);
        X(y[1]);
        X(y[2]);

        // 2. Execute the arithmetic operation
        AddSubtractMultiplication(x, y, r);

         // 3. Measure the results (Target register 'r')
        let results = MResetEachZ(r);

        // 4. Clean up the quantum memory before deallocation
        ResetAll(x);
        ResetAll(y);

        // Return order: LSB to MSB, followed by Carry-out
        return results[1 ...]; 
    }

    operation NaiveMultiplication_Example(): Result[] {
        let n = 3;
        use x = Qubit[n];
        use y = Qubit[n];
        use r = Qubit[2*n];

        // 1. Prepare states
        // Set a = 3 (binary 011 -> a[0]=1, a[1]=1, a[2]=0)
        X(x[0]); 
        X(x[1]);
        // X(x[2]);
        //
        // Set b = 2 (binary 010 -> b[0]=0, b[1]=1, b[2]=0)
        // X(y[0]);
        X(y[1]);
        // X(y[2]);

        // 2. Execute the arithmetic operation
        NaiveMultiplication(x, y, r);

         // 3. Measure the results (Target register 'r')
        let results = MResetEachZ(r);

        // 4. Clean up the quantum memory before deallocation
        ResetAll(x);
        ResetAll(y);

        // Return order: LSB to MSB, followed by Carry-out
        return results; 
    }
    
    operation GidneyAdderWithCarryOut_Example() : Result[] {
        let n = 3;
        use cin = Qubit();
        use a = Qubit[n]; // First addend
        use b = Qubit[n]; // Second accumulator
        use cout = Qubit();

        // 1. Prepare states
        // Set a = 3 (binary 011 -> a[0]=1, a[1]=1, a[2]=0)
        X(a[0]); 
        X(a[1]);
        // X(a[2]);
        //
        // Set b = 2 (binary 010 -> b[0]=0, b[1]=1, b[2]=0)
        // X(b[0]);
        X(b[1]);
        // X(b[2]);

        Message("Executing Gidney Adder: 3 + 2");

        // 2. Execute the arithmetic operation
        GidneyAdderWithCarryOut(cin, a, b, cout);

        // 3. Measure the results (Target register 'b' and 'cout')
        let sum0 = M(b[0]);
        let sum1 = M(b[1]);
        let sum2 = M(b[2]);
        let carryOut = M(cout);

        // 4. Clean up the quantum memory before deallocation
        ResetAll(a);
        ResetAll(b);
        Reset(cin);
        Reset(cout);

        // Return order: LSB to MSB, followed by Carry-out
        return [carryOut, sum2, sum1, sum0]; 
    }

    operation GidneySubtracterWithCarryOut_Example() : Result[] {
        let n = 3;
        use cin = Qubit();
        use a = Qubit[n]; // First addend
        use b = Qubit[n]; // Second accumulator
        use cout = Qubit();

        // 1. Prepare states
        // Set a = 3 (binary 011 -> a[0]=1, a[1]=1, a[2]=0)
        X(a[0]); 
        X(a[1]);
        // X(a[2]);
        //
        // Set b = 2 (binary 010 -> b[0]=0, b[1]=1, b[2]=0)
        // X(b[0]);
        X(b[1]);
        // X(b[2]);

        Message("Executing Gidney Subtracter: 3 - 2");

        // 2. Execute the arithmetic operation
        GidneySubtracterWithCarryOut(cin, a, b, cout);

        // 3. Measure the results (Target register 'b' and 'cout')
        let sum0 = M(b[0]);
        let sum1 = M(b[1]);
        let sum2 = M(b[2]);
        let carryOut = M(cout);

        // 4. Clean up the quantum memory before deallocation
        ResetAll(a);
        ResetAll(b);
        Reset(cin);
        Reset(cout);

        // Return order: LSB to MSB, followed by Carry-out
        return [carryOut, sum2, sum1, sum0]; 
    }
    operation GidneySubtracterWithoutCarryOut_Example() : Result[] {
        let n = 3;
        use cin = Qubit();
        use a = Qubit[n]; // First addend
        use b = Qubit[n]; // Second accumulator

        // 1. Prepare states
        // Set a = 3 (binary 011 -> a[0]=1, a[1]=1, a[2]=0)
        // X(a[0]); 
        X(a[1]);
        // X(a[2]);
        //
        // Set b = 2 (binary 010 -> b[0]=0, b[1]=1, b[2]=0)
        X(b[0]);
        X(b[1]);
        // X(b[2]);

        Message("Executing Gidney Subtracter: 3 - 2");

        // 2. Execute the arithmetic operation
        GidneySubtracterWithoutCarryOut(cin, a, b);

        // 3. Measure the results (Target register 'b' and 'cout')
        let sum0 = M(b[0]);
        let sum1 = M(b[1]);
        let sum2 = M(b[2]);

        // 4. Clean up the quantum memory before deallocation
        ResetAll(a);
        ResetAll(b);
        Reset(cin);

        // Return order: LSB to MSB, followed by Carry-out
        return [sum2, sum1, sum0]; 
    }
}