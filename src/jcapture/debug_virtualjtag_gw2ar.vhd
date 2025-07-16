library ieee;
use ieee.std_logic_1164.all;

entity debug_virtualjtag is
port (
	tck : out std_logic;
	tdi : out std_logic;
	tdo : in std_logic_vector(1 downto 0);
	capture : out std_logic_vector(1 downto 0);
	shift : out std_logic_vector(1 downto 0);
	update : out std_logic_vector(1 downto 0)
);
end entity;

architecture rtl of debug_virtualjtag is
	signal jtck : std_logic;
	signal jtdi,jshift,jupdate,jrstn,jce1,jce2 : std_logic;
	signal jhold : std_logic;
	signal jupdate_d : std_logic;
	signal jtdi_mux : std_logic;
	signal jtdi_latched : std_logic;
	signal jshift_d : std_logic;
	signal selectedreg : std_logic;

	-- JTAG instance needs to be instantiated from verilog in order to leave the
	-- physical pins unconnected and therefore implicit.
	component gwjtag_wrapper is
	port (
		tck_o : out std_logic;--                //DRCK_IN
		tdi_o : out std_logic;--                //TDI_IN
		test_logic_reset_o : out std_logic;--   //RESET_IN
		run_test_idle_er1_o : out std_logic;--   
		run_test_idle_er2_o : out std_logic;   
		shift_dr_capture_dr_o : out std_logic;--//SHIFT_IN|CAPTURE_IN
		pause_dr_o : out std_logic;     
		update_dr_o : out std_logic;--          //UPDATE_IN
		enable_er1_o : out std_logic;--         //SEL_IN
		enable_er2_o : out std_logic;--         //SEL_IN
		tdo_er1_i : in std_logic;--            //TDO_OUT
		tdo_er2_i : in std_logic--             //TDO_OUT
	);
	end component;

begin

	-- The JTAGG instance
	jtg : component gwjtag_wrapper
	port map(
		tck_o => jtck,
		tdi_o => jtdi,
		test_logic_reset_o => jrstn,
		run_test_idle_er1_o => open,
		run_test_idle_er2_o => open,
		shift_dr_capture_dr_o => jshift,
		pause_dr_o => open,
		update_dr_o => jupdate,
		enable_er1_o => jce1,
		enable_er2_o => jce2,
		tdo_er1_i => tdo(0),
		tdo_er2_i => tdo(1)
	);
	tck <= jtck;
	tdi <= jtdi when jshift_d='1' else jtdi_latched;

	process(jtck) begin
		if rising_edge(jtck) then
			jshift_d <= jshift;
			if jshift_d='1' then
				jtdi_latched <= jtdi;
			end if;
		end if;
	end process;

	process(jtck) begin
		if rising_edge(jtck) then
			jupdate_d<=jupdate;
			if jshift='1' then
				jhold <= '1';
			elsif jupdate='0' and jupdate_d='1' then
				jhold <= '0';
			end if;
		end if;
	end process;

	capture(0) <= jce1 and (not jshift) and (not jhold);
	capture(1) <= jce2 and (not jshift) and (not jhold);
	shift(0) <= jce1 and jshift;
	shift(1) <= jce2 and jshift;

	-- Record which register is being accessed, and filter jupdate accordingly.
	process(jtck) begin
		if rising_edge(jtck) then
			if (jce1 and jshift) = '1' then
				selectedreg<='0';
			end if;
			if (jce2 and jshift) = '1' then
				selectedreg<='1';
			end if;
		end if;
	end process;
	update(0) <= jupdate and not selectedreg;
	update(1) <= jupdate and selectedreg;

end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity vjtag_register is
generic (
	bits : integer := 32
);
port (
	-- JTAG clock domain
	tck : in std_logic;
	tdo : out std_logic;
	tdi : in std_logic;
	cap : in std_logic;
	upd : in std_logic;
	shift : in std_logic;
	clk : in std_logic;
	d : in std_logic_vector(bits-1 downto 0);
	q : out std_logic_vector(bits-1 downto 0);
	upd_sys : out std_logic
);
end entity;

architecture rtl of vjtag_register is
	signal shift_next : std_logic_vector(bits-1 downto 0);
	signal shiftreg : std_logic_vector(bits-1 downto 0);
	signal tck_inv : std_logic;
	signal toggle : std_logic := '0';
	signal toggle_s : std_logic_vector(2 downto 0) := (others => '0');
begin
	tdo <= shiftreg(0);

	shift_next <= tdi & shiftreg(bits-1 downto 1);

	process(tck) begin
		if falling_edge(tck) then
			if shift='1' then
				shiftreg<=shift_next;
			end if;

			if cap='1' then
				shiftreg<=d;
			end if;
		end if;
	end process;

	process(tck) begin
		if falling_edge(tck) then
			if upd='1' then
				q<=shift_next;
				toggle <= not toggle;
			end if;
		end if;
	end	process;

	process(clk) begin
		if rising_edge(clk) then
			toggle_s <= toggle & toggle_s(toggle_s'high downto 1);
			upd_sys <= toggle_s(1) xor toggle_s(0);
		end if;
	end process;

end architecture;

