#!/usr/bin/env perl
use strict;
use warnings;

# Native Perl Selenium modules (comes with Selenium::Remote::Driver)
use Selenium::Chrome;
use Log::Log4perl qw(:easy);

# 1. Initialize Logger (Matches your company's logging style)
Log::Log4perl->easy_init($INFO);
my $logger = Log::Log4perl->get_logger();

$logger->info(
    "=================== STARTING WINDOWS UI TEST ===================");

# 2. Test Configuration & Credentials
my $target_url = 'https://demoqa.com';     # Change to your target site
my $username   = 'pdphuong';
my $password   = 'your_secure_password';

# XPaths copied exactly from your framework's typical layout logic
my %XPATHS = (

    # Home Page
    CRD_ELEMENTS => "//h5[text()='Elements']",

    # Elements Page
    TXT_ELEMENTS_PAGE =>
      "//div[text()='Please select an item from left to start practice.']",

    # Text Box Page (placeholders for future test cases)
    TB_CARD           => "//ul[\@class='menu-list']//span[text()='Text Box']",
    TB_TXT_PAGE       => "//h1[text()='Text Box']",
    TB_INPUT_FULLNAME => "//form[\@id='userForm']//input[\@id='userName']",
    TB_INPUT_EMAIL    => "//form[\@id='userForm']//input[\@id='userEmail']",
    TB_INPUT_CURRENT_ADDRESS =>
      "//form[\@id='userForm']//textarea[\@id='currentAddress']",
    TB_INPUT_PERMANENT_ADDRESS =>
      "//form[\@id='userForm']//textarea[\@id='permanentAddress']",
    TB_BTN_SUBMIT => "//form[\@id='userForm']//button[\@id='submit']",

    # Output templates: use %s placeholder (unquoted) for safe value insertion
    TB_OUTPUT_NAME =>
      "//div[\@id='output']//p[\@id='name' and contains(., 'Name: %s')]",
    TB_OUTPUT_EMAIL =>
"//div[\@id='output']//p[\@id='email' and contains(substring-after(text(), ': '), %s)]",
    TB_OUTPUT_CURRENT_ADDRESS =>
"//div[\@id='output']//p[\@id='currentAddress' and contains(substring-after(text(), ': '), %s)]",
    TB_OUTPUT_PERMANENT_ADDRESS =>
"//div[\@id='output']//p[\@id='permanentAddress' and contains(substring-after(text(), ': '), %s)]",

);
############################# TEST EXECUTION LOGIC #############################
# Determine which test cases to run from the command line
my @requested_tests = @ARGV ? @ARGV : qw(TC001);
my %available_tests = (
    TC001 => \&TC001,

    # TC002 => \&TC002,
    # TC003 => \&TC003,
);
my $overall_result = 1;

for my $test_name (@requested_tests) {
    if ( !$available_tests{$test_name} ) {
        $logger->error( "Unknown test case '$test_name'. Available cases: "
              . join( ', ', sort keys %available_tests ) );
        $overall_result = 0;
        next;
    }

    $logger->info("=================== RUNNING $test_name ===================");
    my $result = $available_tests{$test_name}->();
    $logger->info( "=================== $test_name "
          . ( $result ? 'PASSED' : 'FAILED' )
          . " ===================" );
    $overall_result = 0 unless $result;
}

my $final_status = $overall_result ? "PASSED" : "FAILED";
$logger->info(
    "=================== TEST SUITE ENDED: $final_status ===================");

############################### HELPER FUNCTIONS ###############################
# clickElement: Finds an element by XPath and clicks it, with logging and error handling
sub clickElement {
    my ( $driver, $xpath, $label ) = @_;
    $label //= $xpath;
    $logger->info("Clicking element: $label");
    if ( my $element = $driver->find_element( $xpath, 'xpath' ) ) {
        $element->click();
        $logger->info("Clicked element: $label - PASSED");
        return $element;
    }
    else {
        $logger->error("Clicked element: $label - FAILED");
        die "Element not found for click: $label";
    }
}

# inputText: Finds an element by XPath and inputs text, with logging and error handling
sub inputText {
    my ( $driver, $xpath, $text, $label ) = @_;
    $label //= $xpath;
    $logger->info("Inputting text into: $label");
    my $element = $driver->find_element( $xpath, 'xpath' );
    if ($element) {
        $element->send_keys($text);
        $logger->info("Inputted text into: $label - PASSED");
        return $element;
    }
    else {
        $logger->error("Inputting text into: $label - FAILED");
        die "Element not found for input: $label";
    }
    return $element;
}

# inspect: Finds an element by XPath and performs an inspection action (isDisplayed, getText, etc.) with logging and error handling
sub inspect {
    my ( $driver, $xpath, $action, $label ) = @_;
    $label //= $xpath;
    $logger->info("Inspecting element: $action");
    my $element = $driver->find_element( $xpath, 'xpath' );
    die "Element not found for inspect: $action" unless $element;

    if ( $action eq 'isDisplayed' ) {
        return $element->is_displayed();
    }
    elsif ( $action eq 'getText' ) {
        return $element->get_text();
    }
    elsif ( $action eq 'isEnabled' ) {
        return $element->is_enabled();
    }
    elsif ( $action eq 'isSelected' ) {
        return $element->is_selected();
    }
    else {
        die "Unsupported inspect action: $action";
    }
}

# verify_text: Finds an element by XPath and verifies its text matches the expected value, with logging and error handling
sub verify_text {
    my ( $driver, $xpath, $expected, $label ) = @_;
    $label //= $xpath;
    $logger->info("Verifying text on: $label");
    my $element = $driver->find_element( $xpath, 'xpath' );
    die "Element not found for verify: $label" unless $element;
    my $actual = $element->get_text();
    die "Expected text is undefined for $label" unless defined $expected;
    die "Text verification failed for $label: expected '$expected', got '"
      . ( $actual // '' ) . "'"
      unless defined $actual && $actual eq $expected;
    return 1;
}

# xpath_with: safely inject a string value into an XPath template that contains a %s placeholder
sub xpath_with {
    my ( $template, $value ) = @_;

# If the value contains single quotes, build an XPath-safe concat(...) expression
    if ( defined $value && $value =~ /'/ ) {
        my @parts = split /'/, $value, -1;

        # map each part to a single-quoted string
        my @quoted = map { "'$_'" } @parts;

        # join using , "'", to insert the single-quote character between parts
        my $concat = join( q{, "'", }, @quoted );
        return sprintf( $template, "concat($concat)" );
    }
    else {
        # safe simple case: wrap with single quotes
        my $val = defined $value ? "'" . $value . "'" : "''";
        return sprintf( $template, $val );
    }
}

# verifyText: global code ref that asserts the output text equals the expected input
our $verifyText = sub {
    my ( $driver, $template_or_xpath, $expected, $label ) = @_;
    $label //= $template_or_xpath;

 # If caller passed a template key from %XPATHS (contains %s), detect and expand
    my $xpath = $template_or_xpath;
    if ( index( $template_or_xpath, '%s' ) != -1 ) {
        $xpath = xpath_with( $template_or_xpath, $expected );
    }

    $logger->info("Verifying output text for: $label");
    my $element = $driver->find_element( $xpath, 'xpath' );
    die "Element not found for verifyText: $label (xpath: $xpath)"
      unless $element;

    my $actual = $element->get_text();
    $actual = defined $actual ? $actual : '';
    my $exp = defined $expected ? $expected : '';

    # Normalize whitespace for comparison
    $actual =~ s/\s+/ /g;
    $actual =~ s/^\s+|\s+$//g;
    $exp    =~ s/\s+/ /g;
    $exp    =~ s/^\s+|\s+$//g;

    if ( $actual eq $exp ) {
        $logger->info("verifyText passed for $label: '$actual'");
        return 1;
    }
    else {
        die "verifyText failed for $label: expected '$exp', got '$actual'";
    }
};
########################## CLEANUP FUNCTION (Ensures browser is closed after each test) ##########################
sub cleanUp {
    my ($driver) = @_;
    return unless $driver;
    $logger->info("Cleaning up and closing browser instance...");
    $driver->quit();
}
################################# TEST CASES ###############################
sub TC001 () {
    $logger->info(
        "Starting TC001: Navigate to Text Box Page and Input Data...");
    $logger->info("Launching native Chrome Browser via ChromeDriver...");
    my $driver = Selenium::Chrome->new(

# If chromedriver.exe isn't in your PATH, uncomment the line below and specify its path:
# binary => 'C:/path/to/chromedriver.exe'
    );

    # Set a reasonable timeout for finding elements dynamically
    $driver->set_implicit_wait_timeout(5000);

    my $test_result = 1;

    eval {
        my $txt_full_name         = 'John Doe';
        my $txt_email             = 'testing@gmail.com';
        my $txt_current_address   = '123 Main St, Anytown, USA';
        my $txt_permanent_address = '456 Elm St, Othertown, USA';

        # 1. Navigate to Web App
        $logger->info("STEP: Navigating to $target_url");
        $driver->get($target_url);
        $driver->maximize_window();

        # 2. Click DemoQA Elements Card
        my $elements_name = "DemoQA Elements Card";
        clickElement( $driver, $XPATHS{CRD_ELEMENTS}, $elements_name );

        # 3. Verify Successful Navigation (Replicates the 'isdisplayed' check)
        sleep(2);    # Brief pause for page rendering transition
        if (
            inspect(
                $driver,       $XPATHS{TXT_ELEMENTS_PAGE},
                'isDisplayed', 'Elements page intro text'
            )
          )
        {
            $logger->info("STEP: Navigate to Elements page - PASSED");
        }
        else {
            die "STEP: Navigation to Elements page - FAILED";
        }

        #4. Redirect to Text Box Page
        clickElement( $driver, $XPATHS{TB_CARD}, 'Text Box Card' );

        #5 Verify Text Box Page Loaded
        sleep(2);
        if (
            inspect(
                $driver,       $XPATHS{TB_TXT_PAGE},
                'isDisplayed', 'Text Box page header'
            )
          )
        {
            $logger->info("STEP: Navigate to Text Box page - PASSED");
        }
        else {
            die "STEP: Navigation to Text Box page - FAILED";
        }

        #6. Input Data into Text Box
        # Input Full Name
        inputText( $driver, $XPATHS{TB_INPUT_FULLNAME},
            $txt_full_name, 'Full Name' );

        # Input Email
        inputText( $driver, $XPATHS{TB_INPUT_EMAIL}, $txt_email, 'Email' );

        # Input Current Address
        inputText( $driver, $XPATHS{TB_INPUT_CURRENT_ADDRESS},
            $txt_current_address, 'Current Address' );

        # Input Permanent Address
        inputText( $driver, $XPATHS{TB_INPUT_PERMANENT_ADDRESS},
            $txt_permanent_address, 'Permanent Address' );

        #7. Click Submit Button
        clickElement( $driver, $XPATHS{TB_BTN_SUBMIT}, 'Submit Button' );

        #8. Verify Output Data
        sleep(2);

       # Build XPaths from templates and verify outputs contain the input values
        my $name_xpath  = xpath_with( $XPATHS{TB_OUTPUT_NAME}, $txt_full_name );
        my $email_xpath = xpath_with( $XPATHS{TB_OUTPUT_EMAIL}, $txt_email );
        my $current_xpath = xpath_with( $XPATHS{TB_OUTPUT_CURRENT_ADDRESS},
            $txt_current_address );
        my $perm_xpath = xpath_with( $XPATHS{TB_OUTPUT_PERMANENT_ADDRESS},
            $txt_permanent_address );

     # Use inspect to ensure these output elements are displayed
     # Verify outputs match exactly the values we input
     #    $verifyText->( $driver, $name_xpath,  $txt_full_name, 'Output Name' );
     #   $verifyText->( $driver, $email_xpath, $txt_email,     'Output Email' );
     #     $verifyText->(
     #        $driver,              $current_xpath,
     #        $txt_current_address, 'Output Current Address'
     #     );
     #     $verifyText->(
     #        $driver,                $perm_xpath,
     #          $txt_permanent_address, 'Output Permanent Address'
     #      );
        $logger->info($name_xpath);
        $logger->info($email_xpath);
        $logger->info($current_xpath);
        $logger->info($perm_xpath);

        if (
            inspect(
                $driver,       $name_xpath,
                'isDisplayed', 'Output Name verification'
            )
          )
        {
            $logger->info("STEP: Output Name verification - PASSED");
        }
        else {
            die "STEP: Output Name verification - FAILED";
        }
        if (
            inspect(
                $driver,       $email_xpath,
                'isDisplayed', 'Output Email verification'
            )
          )
        {
            $logger->info("STEP: Output Email verification - PASSED");
        }
        else {
            die "STEP: Output Email verification - FAILED";
        }
        if (
            inspect(
                $driver,       $current_xpath,
                'isDisplayed', 'Output Current Address verification'
            )
          )
        {
            $logger->info("STEP: Output Current Address verification - PASSED");
        }
        else {
            die "STEP: Output Current Address verification - FAILED";
        }
        if (
            inspect(
                $driver,       $perm_xpath,
                'isDisplayed', 'Output Permanent Address verification'
            )
          )
        {
            $logger->info(
                "STEP: Output Permanent Address verification - PASSED");
        }
        else {
            die "STEP: Output Permanent Address verification - FAILED";
        }
    };

    if ($@) {
        $logger->error("TEST EXECUTION FAILED! Reason: $@");
        $test_result = 0;
    }

    cleanUp($driver);

    return $test_result;
}

sub TC002 () {
    $logger->info(
        "Starting TC002: Navigate to Text Box Page and Input Data...");
    my $driver = Selenium::Chrome->new(

        # binary => 'C:/path/to/chromedriver.exe'
    );
    $driver->set_implicit_wait_timeout(5000);

    my $test_result = 1;

    eval {
        $logger->info("TC002: Navigating to $target_url");
        $driver->get($target_url);

        $logger->info("TC002: verifying page title or placeholder element");

        # Example placeholder action; update this to your real test step
        # my $element = $driver->find_element($XPATHS{elements_card}, 'xpath');
        # die "Element not found" unless $element && $element->is_displayed();
    };

    if ($@) {
        $logger->error("TC002 FAILED! Reason: $@");
        $test_result = 0;
    }

    cleanUp($driver);
    return $test_result;
}

sub TC003 () {
    $logger->info("Starting TC003: sample tertiary test case...");
    my $driver = Selenium::Chrome->new(

        # binary => 'C:/path/to/chromedriver.exe'
    );
    $driver->set_implicit_wait_timeout(5000);

    my $test_result = 1;

    eval {
        $logger->info("TC003: Navigating to $target_url");
        $driver->get($target_url);

        $logger->info("TC003: verifying page title or placeholder element");

        # Example placeholder action; update this to your real test step
        # my $element = $driver->find_element($XPATHS{elements_card}, 'xpath');
        # die "Element not found" unless $element && $element->is_displayed();
    };

    if ($@) {
        $logger->error("TC003 FAILED! Reason: $@");
        $test_result = 0;
    }

    cleanUp($driver);
    return $test_result;
}
