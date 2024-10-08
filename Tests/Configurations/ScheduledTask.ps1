
configuration CScheduledTaskTestCfg
{
    param(
        $Ensure,
        $Name,
        $TaskXml
    )

    Set-StrictMode -Off

    Import-DscResource -Name '*' -Module 'Carbon.DSC'

    node 'localhost'
    {
        Carbon_ScheduledTask set
        {
            Name = $Name;
            TaskXml = $TaskXml;
            Ensure = $Ensure;
        }
    }
}
