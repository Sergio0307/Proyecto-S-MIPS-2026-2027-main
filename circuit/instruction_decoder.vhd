library ieee;
use ieee.std_logic_1164.all;

entity Instruction_Decoder is
  port (
    OP       : in  std_logic_vector(5 downto 0);
    FUNCT    : in  std_logic_vector(5 downto 0);
    CLASS    : out std_logic_vector(4 downto 0);
    ALU_OP   : out std_logic_vector(2 downto 0);
    EXT_MODE : out std_logic_vector(1 downto 0);
    ILLEGAL  : out std_logic
  );
end entity Instruction_Decoder;

architecture combinational of Instruction_Decoder is
begin
  process (OP, FUNCT)
  begin
    CLASS    <= "11111";
    ALU_OP   <= "000";
    EXT_MODE <= "00";
    ILLEGAL  <= '1';

    if OP = "000000" then
      case FUNCT is
        when "100000" =>
          CLASS <= "00000"; ALU_OP <= "000"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "100001" =>
          CLASS <= "00000"; ALU_OP <= "000"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "100010" =>
          CLASS <= "00000"; ALU_OP <= "001"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "100100" =>
          CLASS <= "00000"; ALU_OP <= "010"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "100101" =>
          CLASS <= "00000"; ALU_OP <= "011"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "101010" =>
          CLASS <= "00000"; ALU_OP <= "100"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "000000" =>
          CLASS <= "00000"; ALU_OP <= "101"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "000010" =>
          CLASS <= "00000"; ALU_OP <= "110"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "001000" =>
          CLASS <= "01111"; ALU_OP <= "000"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "001100" =>
          CLASS <= "10000"; ALU_OP <= "000"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when others =>
          null;
      end case;
    else
      case OP is
        when "001000" =>
          CLASS <= "00001"; ALU_OP <= "000"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "001001" =>
          CLASS <= "00001"; ALU_OP <= "000"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "001010" =>
          CLASS <= "00010"; ALU_OP <= "100"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "001100" =>
          CLASS <= "00011"; ALU_OP <= "010"; EXT_MODE <= "10"; ILLEGAL <= '0';
        when "001101" =>
          CLASS <= "00100"; ALU_OP <= "011"; EXT_MODE <= "10"; ILLEGAL <= '0';
        when "001111" =>
          CLASS <= "00101"; ALU_OP <= "000"; EXT_MODE <= "11"; ILLEGAL <= '0';
        when "100011" =>
          CLASS <= "00110"; ALU_OP <= "000"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "101011" =>
          CLASS <= "00111"; ALU_OP <= "000"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "100000" =>
          CLASS <= "01000"; ALU_OP <= "000"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "100100" =>
          CLASS <= "01001"; ALU_OP <= "000"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "101000" =>
          CLASS <= "01010"; ALU_OP <= "000"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "000100" =>
          CLASS <= "01011"; ALU_OP <= "001"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "000101" =>
          CLASS <= "01100"; ALU_OP <= "001"; EXT_MODE <= "01"; ILLEGAL <= '0';
        when "000010" =>
          CLASS <= "01101"; ALU_OP <= "000"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when "000011" =>
          CLASS <= "01110"; ALU_OP <= "000"; EXT_MODE <= "00"; ILLEGAL <= '0';
        when others =>
          null;
      end case;
    end if;
  end process;
end architecture combinational;
