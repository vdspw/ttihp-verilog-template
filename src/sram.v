module sram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8,
    parameter MEM_SIZE = 1<<ADDR_WIDTH
) (
    input  wire clk,
    input  wire reset_n,
    input  wire chip_enable_n,  // Active low
    input  wire write_enable_n, // Active low
    input  wire read_enable_n,  // Active low
    input  wire [ADDR_WIDTH-1:0] address,
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg  [DATA_WIDTH-1:0] data_out
);
    // State encoding using parameters
    parameter IDLE  = 3'b001;
    parameter WRITE = 3'b010;
    parameter READ  = 3'b100;

    reg [2:0] current_state, next_state;
    reg [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1]; // Memory array
    reg [MEM_SIZE-1:0] addr_one_hot; // One-hot decoding

    // Address one-hot decoding
    always @* begin
        addr_one_hot = {MEM_SIZE{1'b0}};
        if (!chip_enable_n && address < MEM_SIZE) begin
            addr_one_hot[address] = 1'b1;
        end
    end

    // State machine: Next state logic
    always @* begin
        next_state = current_state;
        if (chip_enable_n || !reset_n) begin
            next_state = IDLE;
        end
        else begin
            case (current_state)
                IDLE: begin
                    if (!write_enable_n && read_enable_n && address < MEM_SIZE) begin
                        next_state = WRITE;
                    end
                    else if (!read_enable_n && write_enable_n && address < MEM_SIZE) begin
                        next_state = READ;
                    end
                    else begin
                        next_state = IDLE;
                    end
                end
                WRITE: begin
                    if (write_enable_n || !address < MEM_SIZE) begin
                        next_state = IDLE;
                    end
                end
                READ: begin
                    if (read_enable_n || !address < MEM_SIZE) begin
                        next_state = IDLE;
                    end
                end
                default: next_state = IDLE;
            endcase
        end
    end

    // State machine: State register
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    // Synchronous write
    always @(posedge clk) begin
        if (!reset_n) begin
            // Memory initialization omitted for synthesis compatibility
        end
        else if (current_state == WRITE && !chip_enable_n && !write_enable_n && addr_one_hot[address]) begin
            mem[address] <= data_in;
        end
    end

    // Asynchronous read
    always @* begin
        if (current_state == READ && !chip_enable_n && !read_enable_n && address < MEM_SIZE) begin
            data_out = mem[address];
        end
        else begin
            data_out = {DATA_WIDTH{1'b0}};
        end
    end

endmodule
