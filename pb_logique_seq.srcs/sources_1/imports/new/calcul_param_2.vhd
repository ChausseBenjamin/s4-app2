
---------------------------------------------------------------------------------------------
--    calcul_param_2.vhd   (temporaire)
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--    Université de Sherbrooke - Département de GEGI
--
--    Version         : 5.0
--    Nomenclature    : inspiree de la nomenclature 0.2 GRAMS
--    Date            : 16 janvier 2020, 4 mai 2020
--    Auteur(s)       : 
--    Technologie     : ZYNQ 7000 Zybo Z7-10 (xc7z010clg400-1) 
--    Outils          : vivado 2019.1 64 bits
--
---------------------------------------------------------------------------------------------
--    Description (sur une carte Zybo)
---------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------
-- À FAIRE: 
-- Voir le guide de la problématique
---------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;  -- pour les additions dans les compteurs
USE ieee.numeric_std.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

----------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------
entity calcul_param_2 is
    Port (
    i_bclk    : in   std_logic;   -- bit clock
    i_reset   : in   std_logic;
    i_en      : in   std_logic;   -- un echantillon present
    i_ech     : in   std_logic_vector (23 downto 0);
    o_param   : out  std_logic_vector (7 downto 0)                                     
    );
end calcul_param_2;

----------------------------------------------------------------------------------

architecture Behavioral of calcul_param_2 is

---------------------------------------------------------------------------------
-- States
---------------------------------------------------------------------------------
type state is (awaiting_fresh_sample, calculating_output, overwritting_saved_values);
signal current_state : state;
signal next_state : state;
---------------------------------------------------------------------------------
-- Signaux
---------------------------------------------------------------------------------
-- Rolling average over 3 samples.
signal newest_i2s_signal    : std_logic_vector(23 downto 0); -- saves the i2s input when enable is raised so the state machine can work with it 3 clocks later.
signal most_recent_power    : std_logic_vector(47 downto 0); -- A binary multiplication requires twice as much bits! (2x2 = 4). This one saves the most recent power (received with enable)
signal oldest_power         : std_logic_vector(47 downto 0); -- The oldest received power.
signal calculated_average   : std_logic_vector(47 downto 0);
signal average_on_a_byte    : std_logic_vector(7 downto 0);  -- Saves the output to give to o_

---------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------
-- Q1.23 format. An online converter was used to quickly generate the right signed binary vector for a 31/32 constant factor.
-- Forgetting factor allows the weight of older sample to be less than newer samples to get a quicker mathematical reaction to changes while keeping noises out of the equation.
constant forgetting_factor_31_32 : std_logic_vector(23 downto 0) := "011111000000000000000000";

---------------------------------------------------------------------------------------------
--    Description comportementale
---------------------------------------------------------------------------------------------
begin 
    
    state_manager : process(i_reset, i_bclk)
    begin
        if i_reset = '1' then           
            most_recent_power           <= (others => '0');
            oldest_power                <= (others => '0');
            newest_i2s_signal           <= (others => '0');
            calculated_average          <= (others => '0');
            average_on_a_byte           <= (others => '0');
            current_state               <= awaiting_fresh_sample;
        elsif rising_edge(i_bclk) then -- the clock rose! the state machine can thus go to the wanted state if ever it changed.
            current_state <= next_state;
        end if;
    end process;
    
    power_calculator : process(current_state, i_en)
    begin
        case current_state is
            when awaiting_fresh_sample =>
                if i_en = '1' then -- we have a brand new sample to account for! Save it as it'll be gone by the next clock.
                    newest_i2s_signal <= i_ech;
                    next_state <= calculating_output;
                end if;
                
            when calculating_output =>
                -- Average is the sum of samples divided by the total amount of them.
                -- Using 2 samples allows the average to reach peak (assuming constant 1s inputs) in 100 samples or so. That's 32 in decimal. (29 bits used)
                -- if samples of 0s are introduced at peak... 2 back to back doesn't drop it below 30 before quickly raising again to 32.
                -- Giving it all 0s at peak average quickly drops it to 0 in 100 or so samples as well.
                -- The lower the forgetting factor, the smaller the peak average gets and the quicker it gets there, but the more touched by noise it becomes.
                -- (new*new) + (old * dementia) = new_old, output
                
                -- power is given by the square of the sample! that's cool cuz it also yeets negative numbers!
                most_recent_power <= (newest_i2s_signal * newest_i2s_signal);
                calculated_average <= most_recent_power + (oldest_power * forgetting_factor_31_32);
                
                -- The maximum the average can reach with the selected factor is 32. That's 29 bits. 23 of which are decimals.
                -- I want my power scale to be from 00 to FF... and 31.9999 is basically 011111111....
                -- So if I take into consideration the edge case that we reach 32 (100000) then only taking the MSB for my conversion...
                -- Allows me to "convert" values from 32 to 2 (FF, 01)
                -- And honestly? Good enough for something that will barely see the validation and none of the rapport! Trust!
                if calculated_average >= 32 then -- saturation control!
                    average_on_a_byte <= "11111111";
                else
                    average_on_a_byte <= calculated_average(28 downto 21);
                end if;
                
                next_state <= overwritting_saved_values;

            when overwritting_saved_values =>
                oldest_power <= calculated_average; -- Calculated average becomes the oldest for the next average with newer samples! Rolling average with forgetting factor.
                next_state <= awaiting_fresh_sample;

        end case;
    end process;
    
    -- Output the calculated average on a byte for the 7 segments if the parameter is indeed selected.
    output_management : process(average_on_a_byte)
    begin
        o_param <= average_on_a_byte;
    end process;
--    o_param <= x"02";    -- temporaire ...

end Behavioral;
