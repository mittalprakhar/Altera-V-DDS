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
		MODE_s		: IN  STD_LOGIC;
		VOL_S			: IN  STD_LOGIC;
		SAMPLE_CLK 	: IN  STD_LOGIC;
		RESETN     	: IN  STD_LOGIC;
		L_DATA     	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		R_DATA     	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END TONE_GEN;

ARCHITECTURE gen OF TONE_GEN IS 

	SIGNAL phase_register 		: STD_LOGIC_VECTOR(14 DOWNTO 0);
	SIGNAL tuning_word    		: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL base_tuning_word 	: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL cs_next_tuning_word : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL ns_next_tuning_word	: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL sound_data				: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL mode						: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL note						: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL octave					: STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL volume					: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL desired_volume		: STD_LOGIC_VECTOR(1 DOWNTO 0);
	
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
		address_a => phase_register(14 DOWNTO 7),
		q_a => sound_data -- output is amplitude
	);
	
	-- process to perform DDS
	PROCESS(RESETN, SAMPLE_CLK, CS, NS) BEGIN
		IF RESETN = '0' THEN
			phase_register <= "000000000000000";
			mode <= "00";
		ELSE
			IF RISING_EDGE(SAMPLE_CLK) THEN
				IF mode = "01" THEN
					-- Smooth stopping for tuning word
					IF phase_register = "000000000000000" and not (tuning_word = cs_next_tuning_word) THEN
						tuning_word <= cs_next_tuning_word;
						phase_register <= "000000000000000";
					ELSE
						-- Increment the phase register by the tuning word.
						phase_register <= phase_register + ("000" & tuning_word);
					END IF;

				ELSIF mode = "10" THEN
					-- Smooth stopping for octave-note
					IF phase_register = "000000000000000" and not (tuning_word = ns_next_tuning_word) THEN
						tuning_word <= ns_next_tuning_word;
						phase_register <= "000000000000000";
					ELSE
						-- Increment the phase register by the tuning word.
						phase_register <= phase_register + ("000" & tuning_word);
					END IF;
				END IF;
				
				IF phase_register = "000000000000000" THEN
					volume <= desired_volume;
				END IF;
			END IF;
			
			IF RISING_EDGE(CS) THEN
				IF CS = '1' THEN
					-- Use CMD directly as the value of the tuning word
					cs_next_tuning_word <= CMD(11 DOWNTO 0);
				END IF;
			END IF;
			
			IF RISING_EDGE(NS) THEN
				-- Interpret CMD as note and octave values
				note <= CMD(4 DOWNTO 0);
				octave <= CMD(8 DOWNTO 5);
				
				IF (octave >= "0010" AND note <= "01011") THEN
						-- Set the base tuning word based on the note (0 starts at C)				
					CASE note IS 
						WHEN "00000" => base_tuning_word <= "000000101101";
						WHEN "00001" => base_tuning_word <= "000000101111";
						WHEN "00010" => base_tuning_word <= "000000110010";
						WHEN "00011" => base_tuning_word <= "000000110101";
						WHEN "00100" => base_tuning_word <= "000000111000";
						WHEN "00101" => base_tuning_word <= "000000111100";
						WHEN "00110" => base_tuning_word <= "000000111111";
						WHEN "00111" => base_tuning_word <= "000001000011";
						WHEN "01000" => base_tuning_word <= "000001000111";
						WHEN "01001" => base_tuning_word <= "000001001011";
						WHEN "01010" => base_tuning_word <= "000001010000";
						WHEN "01011" => base_tuning_word <= "000001010100";
						WHEN OTHERS  => base_tuning_word <= "000000000000";
					END CASE;

					-- Left shift the base tuning word by the number of octaves
					-- and set it to the tuning word
					CASE octave IS 
						WHEN "0010" => ns_next_tuning_word <= base_tuning_word(11 DOWNTO 0);
						WHEN "0011" => ns_next_tuning_word <= base_tuning_word(10 DOWNTO 0) & "0";
						WHEN "0100" => ns_next_tuning_word <= base_tuning_word(9 DOWNTO 0) & "00";
						WHEN "0101" => ns_next_tuning_word <= base_tuning_word(8 DOWNTO 0) & "000";
						WHEN "0110" => ns_next_tuning_word <= base_tuning_word(7 DOWNTO 0) & "0000";
						WHEN "0111" => ns_next_tuning_word <= base_tuning_word(6 DOWNTO 0) & "00000";
						WHEN "1000" => ns_next_tuning_word <= base_tuning_word(5 DOWNTO 0) & "000000";
						WHEN OTHERS => ns_next_tuning_word <= "000000000000";
					END CASE;
				ELSE
					-- Smooth Stopping
					base_tuning_word <= "000000000000";
					ns_next_tuning_word <= "000000000000";
				END IF;
			END IF;
			
			IF RISING_EDGE(MODE_S) THEN
				mode <= CMD(1 DOWNTO 0);
			END IF;
			
			IF RISING_EDGE(VOL_S) THEN
				desired_volume <= CMD(1 DOWNTO 0);
			END IF;
		END IF;
		
		CASE volume IS
			WHEN "01" =>
				L_DATA <= sound_data(7) & sound_data(7) & sound_data(7) & sound_data(7) & sound_data & "0000";
				R_DATA <= sound_data(7) & sound_data(7) & sound_data(7) & sound_data(7) & sound_data & "0000";
			WHEN "10" =>
				L_DATA <= sound_data(7) & sound_data(7) & sound_data(7) & sound_data & "00000";
				R_DATA <= sound_data(7) & sound_data(7) & sound_data(7) & sound_data & "00000";
			WHEN "11" =>
				L_DATA <= sound_data(7) & sound_data(7) & sound_data & "000000";
				R_DATA <= sound_data(7) & sound_data(7) & sound_data & "000000";
			WHEN OTHERS =>
				L_DATA <= "0000000000000000";
				R_DATA <= "0000000000000000";
		END CASE;
	END PROCESS;
END gen;
