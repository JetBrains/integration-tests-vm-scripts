using System.Management.Automation;

using JetBrains.Platform.PowerShell.Infra.TeamCity;

namespace JetBrains.Platform.PowerShell.Cmdlet.TeamCity
{
  /// <summary>
  ///   Creates the object for reading all TeamCity properties of the current session (env are available directly with “env:”, while this reads System and Configuration).
  /// </summary>
  [Cmdlet(VerbsCommon.New, "TeamCityProperties")]
  [OutputType(typeof(TeamCityProperties))]
  public class New_TeamCityProperties : System.Management.Automation.Cmdlet
  {
    #region Overrides

    protected override void ProcessRecord()
    {
      WriteObject(new TeamCityProperties());
    }

    #endregion
  }
}