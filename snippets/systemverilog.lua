-- SystemVerilog snippets (LuaSnip). friendly-snippets has more; these are the
-- skeletons for this config's simulate loop (ftplugin/verilog.lua).

return {
  s({ trig = "aff", desc = "always_ff with reset" }, fmt([[
always_ff @(posedge {}) begin
    if ({}) begin
        {}
    end else begin
        {}
    end
end]], { i(1, "clk"), i(2, "rst"), i(3), i(4) })),

  s({ trig = "acomb", desc = "always_comb" }, fmt([[
always_comb begin
    {}
end]], { i(1) })),

  s({ trig = "fsm", desc = "enum state machine" }, fmt([[
typedef enum logic [{}:0] {{ {} }} state_t;
state_t state, next;

always_ff @(posedge clk) begin
    if (rst) state <= {};
    else     state <= next;
end

always_comb begin
    next = state;
    unique case (state)
        {}
    endcase
end]], { i(1, "1"), i(2, "IDLE, RUN"), i(3, "IDLE"), i(4) })),

  -- A testbench that <leader>mr runs and <leader>mw shows.
  s({ trig = "tb", desc = "testbench with a VCD dump" }, fmt([[
module {}_tb;
    logic clk = 0;
    always #5 clk = ~clk;

    {} dut (.*);

    initial begin
        $dumpfile("{}_tb.vcd");
        $dumpvars(0, {}_tb);
        {}
        $finish;
    end
endmodule]], { i(1, "chip"), rep(1), rep(1), rep(1), i(2, "#100;") })),
}
