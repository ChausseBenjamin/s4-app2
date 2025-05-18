--  module_commande.vhd
--  D. Dalle  30 avril 2019, 16 janv 2020, 23 avril 2020
--  module qui permet de réunir toutes les commandes (problematique circuit sequentiels)
--  recues des boutons, avec conditionnement, et des interrupteurs

-- 23 avril 2020 elimination constante mode_seq_bouton: std_logic := '0'

LIBRARY ieee;
USE ieee.std_logic_1164.all;

entity module_commande IS
generic (nbtn : integer := 4;  mode_simulation: std_logic := '0');
    PORT (
          clk              : in  std_logic;
          o_reset          : out  std_logic; 
          i_btn            : in  std_logic_vector (nbtn-1 downto 0); -- signaux directs des boutons
          i_sw             : in  std_logic_vector (3 downto 0);      -- signaux directs des interrupteurs
          o_btn_cd         : out std_logic_vector (nbtn-1 downto 0); -- signaux conditionnés 
          o_selection_fct  :  out std_logic_vector(1 downto 0);
          o_selection_par  :  out std_logic_vector(1 downto 0)
          );
end module_commande;

ARCHITECTURE BEHAVIOR OF module_commande IS
    type sound_effect is (effect_a, effect_b, effect_c, effect_d);
    signal current_sound_effect : sound_effect;
    signal wanted_sound_effect : sound_effect;
--    signal increase_selection : std_logic;
--    signal decrease_selection : std_logic;
--    signal has_pressed_selection_already : std_logic;

component conditionne_btn_v7 is
generic (nbtn : integer := nbtn;  mode_simul: std_logic := '0');
    port (
         CLK          : in std_logic;         -- devrait etre de l ordre de 50 Mhz
         i_btn        : in    std_logic_vector (nbtn-1 downto 0);
         --
         o_btn_db     : out    std_logic_vector (nbtn-1 downto 0);
         o_strobe_btn : out    std_logic_vector (nbtn-1 downto 0)
         );
end component;

    signal d_strobe_btn :    std_logic_vector (nbtn-1 downto 0);
    signal d_btn_cd     :    std_logic_vector (nbtn-1 downto 0); 
    signal d_reset      :    std_logic;
--    signal needs_to_increase : std_logic;
--    signal needs_to_decrease : std_logic;
   
BEGIN 

                  
 inst_cond_btn:  conditionne_btn_v7
    generic map (nbtn => nbtn, mode_simul => mode_simulation)
    port map(
        clk           => clk,
        i_btn         => i_btn,
        o_btn_db      => d_btn_cd,
        o_strobe_btn  => d_strobe_btn  
         );
 
 process(clk)
 begin
    if(rising_edge(clk)) then
        o_reset <= d_reset;
    end if;
 end process;
 
 reset_manager : process(d_reset, clk)
    begin
        if d_reset = '1' then
            current_sound_effect <= effect_a;
        elsif rising_edge(clk) then
            -- Wanted sound effect is outputed on every clock edge
            current_sound_effect <= wanted_sound_effect;
        end if;
    end process;
    
--button_spam_manager : process(d_strobe_btn, d_reset, clk)
--    begin
--        if d_reset = '1' then
--            has_pressed_selection_already <= '0';
--            increase_selection <= '0';
--            decrease_selection <= '0';
--        elsif rising_edge(clk) then
--            -- Managing creating pulses for the button to avoid spam increasing states!
--            if (NOT (has_pressed_selection_already = '1')) AND ((d_strobe_btn(0) = '1') OR (d_strobe_btn(1) = '1')) then
--                -- No increase or decrease is called AND one of the buttons is pressed!
--                -- That means we can send a pulse to increase or decrease the counter.
--                has_pressed_selection_already <= '1';
--                if d_strobe_btn(0) = '1' then
--                    increase_selection <= '1';
--                    decrease_selection <= '0';
--                elsif d_strobe_btn(1) = '1' then
--                    decrease_selection <= '1';
--                    increase_selection <= '0';
--                end if;
--            else
--                increase_selection <= '0';
--                decrease_selection <= '0';
--            end if;
--        else
--            if ((d_strobe_btn(0) = '0') AND (d_strobe_btn(1) = '0')) then
--                -- no buttons is pressed. Therefor, we can start registering an increase or decrease again.
--                has_pressed_selection_already <= '0';
--            end if;
--        end if;
--    end process;

state_manager : process(clk, current_sound_effect, d_strobe_btn)
    begin
        if rising_edge(clk) then
            case current_sound_effect is
                when effect_a =>
                    o_selection_fct <= "00";
                    case d_strobe_btn(1 downto 0) is
                        when "01" =>
                            wanted_sound_effect <= effect_b;
                        when "10" =>
                            wanted_sound_effect <= effect_d;
                        when others =>
                            -- Do nothing. It's not specified.
                    end case;
                
                when effect_b =>
                    o_selection_fct <= "01";
                    case d_strobe_btn(1 downto 0) is
                        when "01" =>
                            wanted_sound_effect <= effect_c;
                        when "10" =>
                            wanted_sound_effect <= effect_a;
                        when others =>
                            -- Do nothing. It's not specified.
                    end case;

                when effect_c =>
                    o_selection_fct <= "10";
                    case d_strobe_btn(1 downto 0) is
                        when "01" =>
                            wanted_sound_effect <= effect_d;
                        when "10" =>
                            wanted_sound_effect <= effect_b;
                        when others =>
                            -- Do nothing. It's not specified.
                    end case;
                
                when effect_d =>
                    o_selection_fct <= "11";
                    case d_strobe_btn(1 downto 0) is
                        when "01" =>
                            wanted_sound_effect <= effect_a;
                        when "10" =>
                            wanted_sound_effect <= effect_c;
                        when others =>
                            -- Do nothing. It's not specified.
                    end case;
            end case;
        END IF;
    end process;
 
   o_btn_cd        <= d_btn_cd;
   o_selection_par <= i_sw(1 downto 0); -- mode de selection du parametre par sw
   --o_selection_fct <= i_sw(3 downto 2); -- mode de selection de la fonction par sw
   d_reset         <= i_btn(3);         -- pas de contionnement particulier sur reset

END BEHAVIOR;
