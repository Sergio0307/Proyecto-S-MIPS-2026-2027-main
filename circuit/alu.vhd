library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALU is
  port (
    A      : in  std_logic_vector(31 downto 0);
    B      : in  std_logic_vector(31 downto 0);
    ALU_OP : in  std_logic_vector(2 downto 0);
    RESULT : out std_logic_vector(31 downto 0);
    ZERO   : out std_logic
  );
end entity ALU;

architecture combinational of ALU is
  signal result_i : std_logic_vector(31 downto 0);
  signal shamt    : natural range 0 to 31;
  constant ZERO32 : std_logic_vector(31 downto 0) := (others => '0');
begin
  shamt <= to_integer(unsigned(B(4 downto 0)));

  process (A, B, ALU_OP, shamt)
  begin
    case ALU_OP is
      when "000" =>
        result_i <= std_logic_vector(unsigned(A) + unsigned(B));
      when "001" =>
        result_i <= std_logic_vector(unsigned(A) - unsigned(B));
      when "010" =>
        result_i <= A and B;
      when "011" =>
        result_i <= A or B;
      when "100" =>
        if signed(A) < signed(B) then
          result_i <= std_logic_vector(to_unsigned(1, 32));
        else
          result_i <= ZERO32;
        end if;
      when "101" =>
        result_i <= std_logic_vector(shift_left(unsigned(A), shamt));
      when "110" =>
        result_i <= std_logic_vector(shift_right(unsigned(A), shamt));
      when others =>
        result_i <= ZERO32;
    end case;
  end process;

  RESULT <= result_i;
  ZERO   <= '1' when result_i = ZERO32 else '0';
end architecture combinational;
