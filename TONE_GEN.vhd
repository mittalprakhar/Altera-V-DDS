-- DDS tone generator.
-- 12-bit tuning word
-- 15-bit phase register
-- 256 x 8-bit ROM.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

LIBRARY ALTERA_MF;
USE ALTERA_MF.ALTERA_MF_COMPONENTS.ALL;


ENTITY TONE_GEN IS 
	PORT
	(
		CMD			: IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
		CS         	: IN  STD_LOGIC;
		NS				: IN  STD_LOGIC;
		SAMPLE_CLK 	: IN  STD_LOGIC;
		RESETN     	: IN  STD_LOGIC;
		L_DATA     	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		R_DATA     	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END TONE_GEN;

ARCHITECTURE gen OF TONE_GEN IS 

	SIGNAL phase_register 	: STD_LOGIC_VECTOR(14 DOWNTO 0);
	SIGNAL tuning_word    	: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL sound_data			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL note					: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL octave				: STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL base_tuning_word : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL cs_or_ns			: STD_LOGIC;
	
BEGIN

	-- ROM to hold the waveform
	SOUND_LUT : altsyncram
	GENERIC MAP (
		lpm_type => "altsyncram",
		width_a => 8,
		widthad_a => 8,
		numwords_a => 256,
		init_file => "SOUND_SINE.mif",
		intended_device_family => "Cyclone II",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		operation_mode => "ROM",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		power_up_uninitialized => "FALSE"
	)
	PORT MAP (
		clock0 => NOT(SAMPLE_CLK),
		-- In this design, seven bits of the phase register are fractional bits
		address_a => phase_register(14 downto 7),
		q_a => sound_data -- output is amplitude
	);
	
	-- 8-bit sound data is used as bits 12-5 of the 16-bit output.
	-- This is to prevent the output from being too loud.
	L_DATA(15 DOWNTO 13) <= sound_data(7) & sound_data(7) & sound_data(7); -- sign extend
	L_DATA(12 DOWNTO 5) <= sound_data;
	L_DATA(4 DOWNTO 0) <= "00000"; -- pad right side with 0s
	
	-- Right channel is the same.
	R_DATA(15 DOWNTO 13) <= sound_data(7) & sound_data(7) & sound_data(7); -- sign extend
	R_DATA(12 DOWNTO 5) <= sound_data;
	R_DATA(4 DOWNTO 0) <= "00000"; -- pad right side with 0s
	
	-- Custom clock signal combining CS and NS modes
	cs_or_ns <= CS or NS;
	
	-- process to perform DDS
	PROCESS(RESETN, SAMPLE_CLK) BEGIN
		IF RESETN = '0' THEN
			phase_register <= "000000000000000";
		ELSIF RISING_EDGE(SAMPLE_CLK) THEN
			IF tuning_word = "000000000000" THEN  -- if command is 0, return to 0 output.
				phase_register <= "000000000000000";
			ELSE
				-- Increment the phase register by the tuning word.
				phase_register <= phase_register + ("000" & tuning_word);
			END IF;
		END IF;
	END PROCESS;

	PROCESS(RESETN, cs_or_ns) BEGIN
		IF RESETN = '0' THEN
			tuning_word <= "000000000000";
		ELSIF RISING_EDGE(cs_or_ns) THEN
			IF CS = '1' THEN
				-- Use CMD directly as the value of the tuning word
				tuning_word <= CMD(11 DOWNTO 0);
			ELSE
				-- Interpret CMD as note and octave values
				note <= CMD(4 DOWNTO 0);
				octave <= CMD(8 DOWNTO 5);
				
				--Valid note and octave values
				IF (octave >= "0010" AND note <= "01011") THEN
					-- Set the base tuning word based on the note (0 starts at C)
					case note is 
						when "00000" => base_tuning_word <= "000000101101";
						when "00001" => base_tuning_word <= "000000101111";
						when "00010" => base_tuning_word <= "000000110010";
						when "00011" => base_tuning_word <= "000000110101";
						when "00100" => base_tuning_word <= "000000111000";
						when "00101" => base_tuning_word <= "000000111100";
						when "00110" => base_tuning_word <= "000000111111";
						when "00111" => base_tuning_word <= "000001000011";
						when "01000" => base_tuning_word <= "000001000111";
						when "01001" => base_tuning_word <= "000001001011";
						when "01010" => base_tuning_word <= "000001010000";
						when "01011" => base_tuning_word <= "000001010100";
						when others  => base_tuning_word <= "000000000000";
					end case;

					-- Left shift the base tuning word by the number of octaves
					-- and set it to the tuning word
					case octave is 
						when "0010" => tuning_word <= base_tuning_word(11 DOWNTO 0);
						when "0011" => tuning_word <= base_tuning_word(10 DOWNTO 0) & "0";
						when "0100" => tuning_word <= base_tuning_word(9 DOWNTO 0) & "00";
						when "0101" => tuning_word <= base_tuning_word(8 DOWNTO 0) & "000";
						when "0110" => tuning_word <= base_tuning_word(7 DOWNTO 0) & "0000";
						when "0111" => tuning_word <= base_tuning_word(6 DOWNTO 0) & "00000";
						when "1000" => tuning_word <= base_tuning_word(5 DOWNTO 0) & "000000";
						when others => tuning_word <= "000000000000";
					end case;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END gen;