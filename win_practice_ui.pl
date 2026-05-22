#!/usr/bin/env perl
use strict;
use warnings;

# Native Perl Selenium modules (comes with Selenium::Remote::Driver)
use Selenium::Chrome; 
use Log::Log4perl qw(:easy);

# 1. Initialize Logger (Matches your company's logging style)
Log::Log4perl->easy_init($INFO);
my $logger = Log::Log4perl->get_logger();

$logger->info("=================== STARTING WINDOWS UI TEST ===================");

# 2. Test Configuration & Credentials
my $target_url = 'https://demoqa.com'; # Change to your target site
my $username   = 'pdphuong';
my $password   = 'your_secure_password';

# XPaths copied exactly from your framework's typical layout logic
my %XPATHS = (
    username_field => "//*[\@id='username']", # Change to match actual page elements
    password_field => "//*[\@id='password']",
    submit_button  => "//*[\@id='submit'] || //button[\@type='submit']",
    success_marker => "//*[\@id='dashboard']", # Element visible only after successful login
);

# 3. Launch Chrome Browser
$logger->info("Launching native Chrome Browser via ChromeDriver...");
my $driver = Selenium::Chrome->new(
    # If chromedriver.exe isn't in your PATH, uncomment the line below and specify its path:
    # binary => 'C:/path/to/chromedriver.exe'
);

# Set a reasonable timeout for finding elements dynamically
$driver->set_implicit_wait_timeout(5000); 

my $result = 1; # Track test status

eval {
    # 4. Navigate to Web App
    $logger->info("STEP: Navigating to $target_url");
    $driver->get($target_url);
    $driver->maximize_window();

    # 5. Execute Login Sequence (Replicates UIUtils.pm)
    $logger->info("STEP: Inputting username: '$username'");
    my $user_el = $driver->find_element($XPATHS{username_field}, 'xpath');
    $user_el->send_keys($username);

    $logger->info("STEP: Inputting password");
    my $pass_el = $driver->find_element($XPATHS{password_field}, 'xpath');
    $pass_el->send_keys($password);

    $logger->info("STEP: Clicking 'Sign In' button");
    my $submit_el = $driver->find_element($XPATHS{submit_button}, 'xpath');
    $submit_el->click();

    # 6. Verify Successful Login (Replicates the 'isdisplayed' check)
    sleep(2); # Brief pause for page rendering transition
    my $success_el = $driver->find_element($XPATHS{success_marker}, 'xpath');
    
    if ($success_el && $success_el->is_displayed()) {
        $logger->info("STEP: Login successfully - PASSED");
    } else {
        die "Login success marker element not found or not displayed.";
    }

    # 7. Add further Navigation actions here if needed
    # my $nav_el = $driver->find_element("//*[@id='menu-item']", 'xpath');
    # $nav_el->click();

};

# 8. Exception & Error Handling
if ($@) {
    $logger->error("TEST EXECUTION FAILED! Reason: $@");
    $result = 0;
}

# 9. Cleanup & Shutdown Session
$logger->info("Cleaning up and closing browser instance...");
$driver->quit();

my $final_status = $result ? "PASSED" : "FAILED";
$logger->info("=================== TEST ENDED: $final_status ===================");